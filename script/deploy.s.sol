// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "src/fractional/ERC20TokenCenter.sol";
import "src/fractional/ERC721VaultFactory.sol";
import "src/nft/CarbonCreditNFT.sol";
import "src/nft/CO2eCertificateNFT.sol";
import "src/nft/UUIDGenerator.sol";

contract Deploy is Script {
    ERC20TokenCenter erc20TokenCenter;
    CarbonCreditNFT carbonCreditNFT;
    ERC721VaultFactory erc721VaultFactory;
    CO2eCertificateNFT co2eCertificateNFT;
    UUIDGenerator uuidGen;
    
    function run() public {
        uint256 deployerPriKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPriKey);
        
        // Deploy `ERC20TokenCenter.sol`
        erc20TokenCenter = new ERC20TokenCenter(
            vm.envString("DEPLOY_ERC20_TOKEN_CENTER_ARG0"),
            vm.envString("DEPLOY_ERC20_TOKEN_CENTER_ARG1"),
            uint8(vm.envUint("DEPLOY_ERC20_TOKEN_CENTER_ARG2"))
        );
        
        // Deploy `CarbonCreditNFT.sol`
        carbonCreditNFT = new CarbonCreditNFT(
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ARG0"),
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ARG1")
        );
        carbonCreditNFT.addSource(
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ADD_SOURCE")
        );
        carbonCreditNFT.addIssueBy(
            vm.envString("DEPLOY_CARBON_CREDIT_NFT_ADD_ISSUE_BY_ARG0"),
            uint16(vm.envUint("DEPLOY_CARBON_CREDIT_NFT_ADD_ISSUE_BY_ARG1"))
        );
        
        // Deploy `ERC721VaultFactory.sol`
        erc721VaultFactory = new ERC721VaultFactory(
            address(erc20TokenCenter),
            address(carbonCreditNFT)
        );
        
        // Deploy `UUIDGenerator.sol`
        uuidGen = new UUIDGenerator();
        
        // Deploy `CO2eCertificateNFT.sol`
        co2eCertificateNFT = new CO2eCertificateNFT(
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG0"),
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG1"),
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG2"),
            vm.envString("DEPLOY_CO2E_CERTIFICATE_NFT_ARG3"),
            uint16(vm.envUint("DEPLOY_CO2E_CERTIFICATE_NFT_ARG4")),
            address(erc20TokenCenter),
            address(uuidGen)
        );
        
        // Set important parameters in `ERC20TokenCenter.sol`
        erc20TokenCenter.setERC721VaultFactory(
            address(erc721VaultFactory)
        );
        erc20TokenCenter.setCO2eCertificateNFT(
            address(co2eCertificateNFT)
        );
        
        vm.stopBroadcast();
    }
}