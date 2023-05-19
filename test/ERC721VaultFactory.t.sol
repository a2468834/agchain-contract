// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/fractional/ERC20TokenCenter.sol";
import "src/fractional/ERC721VaultFactory.sol";
import "src/nft/CarbonCreditNFT.sol";

contract TestERC721VaultFactory is Test {
    ERC20TokenCenter   tokenCenter;
    CarbonCreditNFT    authorizedNFT;
    ERC721VaultFactory vaultFactory;
    
    address receiver = address(0xabcd);
    uint256 token_id = 0;
    uint256 vault_id = 0;
    
    event Mint(uint256 indexed tokenId, address vault, uint256 vaultId);
    
    function foo(bytes32 _hash, bytes calldata _signature) public returns (bytes4) {
        return vaultFactory.isValidSignature(_hash, _signature);
    }
    
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
        
        tokenCenter.setERC721VaultFactory(address(vaultFactory));
        
        authorizedNFT.mintToken(
            CarbonCreditNFT.NewTokenData(
                "1st certificate",
                0,
                0,
                123456
            ),
            receiver
        );
        assertEq(authorizedNFT.ownerOf(token_id), receiver);
    }
    
    function testFractionalization() public {
        vm.startPrank(receiver);
        
        vm.expectRevert("Please give NFT transferring permission to `ERC721VaultFactory`");
        vaultFactory.fractionalization(token_id);
        
        authorizedNFT.approve(address(vaultFactory), token_id);
        vm.expectEmit(true, false, true, false);
        emit Mint(token_id, address(0x0), vault_id);
        vaultFactory.fractionalization(token_id);
        
        vm.stopPrank();
    }
    
    function testIsValidSignature() public {
        bytes memory dont_care = bytes.concat(bytes32(0x0));
        bytes32 dont_care_hash = keccak256(dont_care);
        
        vm.expectRevert("Invalid caller of `isValidSignature()`");
        this.foo(dont_care_hash, dont_care);
    }
}