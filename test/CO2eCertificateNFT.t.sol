// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/fractional/ERC20TokenCenter.sol";
import "src/fractional/ERC721VaultFactory.sol";
import "src/nft/CarbonCreditNFT.sol";
import "src/nft/CO2eCertificateNFT.sol";
import "src/nft/UUIDGenerator.sol";

contract TestCO2eCertificateNFT is Test {
    ERC20TokenCenter   tokenCenter;
    ERC721VaultFactory vaultFactory;
    CarbonCreditNFT    authorizedNFT;
    UUIDGenerator      uuidGen;
    CO2eCertificateNFT co2eToken;
    
    address receiver = address(0xabcd);
    
    function setUp() public {
        tokenCenter = new ERC20TokenCenter(
            vm.envString("DEPLOY_ERC20_TOKEN_CENTER_ARG0"),
            vm.envString("DEPLOY_ERC20_TOKEN_CENTER_ARG1"),
            uint8(vm.envUint("DEPLOY_ERC20_TOKEN_CENTER_ARG2"))
        );
                
        authorizedNFT = new CarbonCreditNFT(
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ARG0"),
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ARG1")
        );
        authorizedNFT.addSource(
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ADD_SOURCE")
        );
        authorizedNFT.addIssueBy(
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ADD_ISSUE_BY_ARG0"),
            uint16(vm.envUint("DEPLOY_CARBON_CREDIT_NFT_ADD_ISSUE_BY_ARG1"))
        );
        
        vaultFactory = new ERC721VaultFactory(
            address(tokenCenter),
            address(authorizedNFT)
        );
        
        uuidGen = new UUIDGenerator();
        
        co2eToken = new CO2eCertificateNFT(
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG0"),
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG1"),
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG2"),
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG3"),
            uint16(vm.envUint("DEPLOY_CO2E_CERTIFICATE_NFT_ARG4")),
            address(tokenCenter),
            address(uuidGen)
        );
        
        tokenCenter.setERC721VaultFactory(address(vaultFactory));
        tokenCenter.setCO2eCertificateNFT(address(co2eToken));
    }
    
    /**
     * @dev We assume the EOA has enough Carbon Credit FTs to complete calling
     *      `CO2eCertificateNFT.mintToken()` process. Test case for trying to
     *      spend more tokens than they have is written in the
     *      `ERC20TokenCenter.t.sol`.
     */
    function testMintToken() public {
        vm.expectRevert("Caller is not allowed to invoke this function");
        co2eToken.mintToken(receiver, 1234);
        
        vm.expectRevert("`amount` must be at least `minSwapAmount` Carbon Credit FTs");
        vm.prank(address(tokenCenter));
        co2eToken.mintToken(receiver, 123);
        
        vm.expectRevert("Conversion `amount` must be a multiple of `ratio`");
        vm.prank(address(tokenCenter));
        co2eToken.mintToken(receiver, 1234);
        
        uint256 giantAmount = uint256(type(uint72).max) * 1000;
        vm.expectRevert("Try to convert overwhelming amount of Carbon Credit FTs");
        vm.prank(address(tokenCenter));
        co2eToken.mintToken(receiver, giantAmount);
        
        // Normal functionality
        tokenCenter.mintToken(address(tokenCenter), 123000);
        vm.startPrank(address(tokenCenter));
        tokenCenter.approve(address(co2eToken), 123000);
        uint256 newTokenId = co2eToken.mintToken(receiver, 123000);
        // emit log_string(co2eToken.tokenURI(newTokenId));
        vm.stopPrank();
    }
}