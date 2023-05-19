// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/fractional/ERC20TokenCenter.sol";
import "src/fractional/ERC721VaultFactory.sol";
import "src/nft/CarbonCreditNFT.sol";
import "src/nft/CO2eCertificateNFT.sol";
import "src/nft/UUIDGenerator.sol";

contract TestERC20TokenCenter is Test {
    ERC20TokenCenter   tokenCenter;
    ERC721VaultFactory vaultFactory;
    CarbonCreditNFT    authorizedNFT;
    UUIDGenerator      uuidGen;
    CO2eCertificateNFT co2eToken;
    
    address receiver = address(0xabcd);
    uint256 token_id = 0;
    uint256 vault_id = 0;
    
    event AllowanceRecord(address indexed owner, address indexed spender, uint256 prevAmount, uint256 currAmount);
    event ExchangeToERC20(address indexed originalNFT, uint256 indexed vaultId, uint256 ratio, uint256 supply);
    event ExchangeToERC721(address indexed issuingNFT, uint256 tokenId);
    event TransferByPlatform(address indexed from, address indexed spender, address to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    
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
        tokenCenter.setERC721VaultFactory(
            address(vaultFactory)
        );
        tokenCenter.setCO2eCertificateNFT(
            address(co2eToken)
        );
    }
    
    function testCallERC1271isValidSignature() public {
        // Tamper `ERC721VaultFactory` with given values
        vm.store(
            address(vaultFactory),
            bytes32(uint256(2)), // Slot index of `maxVaultId` is 2
            bytes32(uint256(vault_id + 1))
        );
        vm.store(
            address(vaultFactory),
            keccak256(abi.encode(vault_id, 3)), // Slot index of `vaults` is 3
            bytes32(abi.encode(address(0x1234)))
        );
        
        tokenCenter.callERC1271isValidSignature(
            keccak256(abi.encode(address(0x1234), vault_id)),
            abi.encode(address(0x1234), vault_id)
        );
    }
    
    function testSetERC721VaultFactory() public {
        vm.expectRevert("Cannot set the same address twice");
        tokenCenter.setERC721VaultFactory(address(vaultFactory));
        
        tokenCenter.setERC721VaultFactory(address(0x1234));
        assertEq(address(tokenCenter.erc721VaultFactory()), address(0x1234));
    }
    
    function testSetCO2eCertificateNFT() public {
        vm.expectRevert("Cannot set the same address twice");
        tokenCenter.setCO2eCertificateNFT(address(co2eToken));
        
        tokenCenter.setCO2eCertificateNFT(address(0x1234));
        assertEq(address(tokenCenter.co2eCertificateNFT()), address(0x1234));
    }
    
    function testMintToken() public {
        address lala = address(0x1234);
        uint256 weee = 4321;
        
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(lala);
        tokenCenter.mintToken(lala, weee);
        assertEq(tokenCenter.balanceOf(lala), 0);
        
        // Normal functionality
        tokenCenter.mintToken(lala, weee);
        assertEq(tokenCenter.balanceOf(lala), weee);
    }
    
    function testBurnToken() public {
        address lala = address(0x1234);
        uint256 weee = 43210;
        tokenCenter.mintToken(lala, weee);
        
        vm.expectRevert("Caller is not allowed to invoke this function");
        vm.prank(lala);
        tokenCenter.burnToken(lala, weee);
        assertEq(tokenCenter.balanceOf(lala), weee);
        
        // Normal functionality
        vm.prank(address(this));
        tokenCenter.burnToken(lala, weee / 2);
        assertEq(tokenCenter.balanceOf(lala), weee / 2);
        vm.prank(address(co2eToken));
        tokenCenter.burnToken(lala, weee / 2);
        assertEq(tokenCenter.balanceOf(lala), 0);
    }
    
    function testExchangeTokenToFT() public {
        // Tamper `ERC721VaultFactory` with a given value
        vm.store(address(vaultFactory), bytes32(uint256(2)), bytes32(uint256(vault_id + 1)));
        
        // Called by owner
        vm.expectRevert("Failed to call `ERC721VaultFactory`'s `isValidSignature()`");
        tokenCenter.exchangeToken(receiver, vault_id, address(authorizedNFT), 123000, 1000);
        
        // Called by EOA
        vm.expectRevert("Failed to call `ERC721VaultFactory`'s `isValidSignature()`");
        vm.prank(receiver);
        tokenCenter.exchangeToken(receiver, vault_id, address(authorizedNFT), 123000, 1000);
        
        // Called by `ERC20TokenCenter`
        vm.expectRevert("Failed to call `ERC721VaultFactory`'s `isValidSignature()`");
        vm.prank(address(tokenCenter));
        tokenCenter.exchangeToken(receiver, vault_id, address(authorizedNFT), 123000, 1000);
        
        // Called by zero address
        vm.expectRevert("Failed to call `ERC721VaultFactory`'s `isValidSignature()`");
        vm.prank(address(0x0));
        tokenCenter.exchangeToken(receiver, vault_id, address(authorizedNFT), 123000, 1000);
        
        // Normal functionality
        address tokenVaultAddress = address(0x1234);
        vm.store(address(vaultFactory), keccak256(abi.encode(vault_id, 3)), bytes32(abi.encode(tokenVaultAddress)));
        vm.prank(tokenVaultAddress);
        vm.expectEmit(true, true, true, true);
        emit ExchangeToERC20(address(authorizedNFT), vault_id, 1000, 123000);
        tokenCenter.exchangeToken(
            receiver,
            vault_id,
            address(authorizedNFT),
            123000,
            1000
        );
    }
    
    function testExchangeTokenToNFT() public {
        tokenCenter.mintToken(receiver, 123000);
        
        vm.expectRevert("Carbon Credit FT allowance is not enough for now");
        vm.prank(receiver);
        tokenCenter.exchangeToken(receiver, 123000);
        
        // Normal functionality
        vm.startPrank(receiver);
        tokenCenter.approve(address(tokenCenter), 123000);
        vm.expectEmit(true, true, true, true);
        emit ExchangeToERC721(address(co2eToken), token_id);
        tokenCenter.exchangeToken(receiver, 123000);
        vm.stopPrank();
    }
    
    function testIncreaseAllowance() public {
        vm.expectRevert("Cannot approve from the zero address");
        vm.prank(address(0x0));
        tokenCenter.increaseAllowance(receiver, 5678);
        
        vm.expectRevert("Cannot approve to the zero address");
        tokenCenter.increaseAllowance(address(0x0), 5678);
        
        vm.expectEmit(true, true, true, true);
        emit AllowanceRecord(
            address(this),
            receiver,
            0,
            5678
        );
        tokenCenter.increaseAllowance(receiver, 5678);
    }
    
    function testDecreaseAllowance() public {
        tokenCenter.approve(receiver, 9999);
        
        vm.expectRevert("Cannot approve from the zero address");
        vm.prank(address(0x0));
        tokenCenter.decreaseAllowance(receiver, 1234);
        
        vm.expectRevert("Cannot approve to the zero address");
        tokenCenter.decreaseAllowance(address(0x0), 1234);
        
        vm.expectRevert("Try to decrease allowance below zero");
        tokenCenter.decreaseAllowance(receiver, 99999);
        
        vm.expectEmit(true, true, true, true);
        emit AllowanceRecord(
            address(this),
            receiver,
            9999,
            8765
        );
        tokenCenter.decreaseAllowance(receiver, 1234);
    }
    
    function testTransferFrom() public {
        address platform    = address(this);
        address third_party = address(0x1234);
        address dont_care   = address(0xffff);
        
        tokenCenter.mintToken(receiver, 123456);
        
        // Normal `transferFrom()`
        vm.prank(receiver);
        tokenCenter.approve(third_party, 61728);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(receiver, dont_care, 61728);
        vm.prank(third_party);
        tokenCenter.transferFrom(receiver, dont_care, 61728);
        
        // `transferFrom()` is called by platform
        vm.prank(receiver);
        tokenCenter.approve(platform, 61728);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(receiver, dont_care, 61728);
        vm.expectEmit(true, true, true, true);
        emit TransferByPlatform(receiver, platform, dont_care, 61728);
        vm.prank(platform);
        tokenCenter.transferFrom(receiver, dont_care, 61728);
    }
}