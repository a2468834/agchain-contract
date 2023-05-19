// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC20TokenCenter.sol";
import "./ERC721TokenVault.sol";
import "../nft/CarbonCreditNFT.sol";

contract ERC721VaultFactory is Ownable, ReentrancyGuard, IERC1271 {
    /******************************** Constant ********************************/
    ERC20TokenCenter public immutable erc20TokenCenter;
    CarbonCreditNFT  public immutable authorizedNFT;
    
    /********************************** Event *********************************/
    // Emit when a new `TokenVault` is created
    event Mint(
        uint256 indexed tokenId,
        address vault,
        uint256 vaultId
    );
    
    /***************************** State veriable *****************************/
    // The minimal "un-used" `vaultId`, i.e., the maximum "used" `(vaultId + 1)`
    uint256 public maxVaultId;
    
    // A whitelist mapping from `vaultId` to the address of vault
    mapping(uint256 => address) public vaults;
    
    /****************************** Constructor *******************************/
    constructor(address _erc20TokenCenter, address _authorizedNFT) {
        erc20TokenCenter = ERC20TokenCenter(_erc20TokenCenter);
        authorizedNFT = CarbonCreditNFT(_authorizedNFT);
    }
    
    /************************* Public write function **************************/
    /**
     * @dev Fractionalize the ERC721 token
     * 
     * This function is meant to be called by anyone who owns `authorizedNFT`.
     * Please be aware of granting permission to `ERC721VaultFactory` for
     * transferring token, otherwise it will revert.
     * 
     * @param tokenId Token identifier of `authorizedNFT`
     */
    function fractionalization(uint256 tokenId) public nonReentrant returns (uint256) {
        // Check if `tokenId` is avaliable for transferring by `address(this)`
        require(
            authorizedNFT.getApproved(tokenId) == address(this),
            "Please give NFT transferring permission to `ERC721VaultFactory`"
        );
        
        // Predict contract address of the new TokenVault
        uint256 curVaultId = maxVaultId++;
        bytes32 salt = bytes32(curVaultId) ^ bytes32(block.difficulty);
        address predictedAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(abi.encodePacked(
                type(ERC721TokenVault).creationCode,
                abi.encode(
                    erc20TokenCenter,
                    authorizedNFT,
                    tokenId,
                    msg.sender,
                    curVaultId
                )
            ))
        )))));
        
        // Transfer `msg.sender`'s NFT to the new TokenVault
        try authorizedNFT.safeTransferFrom(msg.sender, predictedAddress, tokenId) {
        } catch {
            revert("Failed to transfer NFT from the owner to the `TokenVault`");
        }
        
        // Store new TokenVault address into the whitelist which will let `ERC20TokenCenter` know later
        vaults[curVaultId] = predictedAddress;
        emit Mint(tokenId, predictedAddress, curVaultId);
        
        // Establish new TokenVault by `CREATE2`
        ERC721TokenVault newTokenVault = new ERC721TokenVault{salt: salt}(
            erc20TokenCenter,
            authorizedNFT,
            tokenId,
            msg.sender,
            curVaultId
        );
        require(
            address(newTokenVault) == predictedAddress,
            "Predicting address is failed, so revert NFT transferring"
        );
        
        return curVaultId;
    }
    
    /************************** Overriding function ***************************/
    function isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view override returns (bytes4) {
        // Check whether the caller is `ERC20TokenCenter`
        require(msg.sender == address(erc20TokenCenter), "Invalid caller of `isValidSignature()`");
        
        // Split the signature
        address prevMsgSender;
        uint256 vaultId;
        (prevMsgSender, vaultId) = abi.decode(_signature, (address, uint256));
        
        // Validate signatures
        require(_hash == keccak256(_signature), "`_signature` is differnet from `_hash`");
        require(vaultId < maxVaultId, "Invalid `vaultId`");
        require(prevMsgSender != address(0), "Caller cannot be the zero address");
        require(vaults[vaultId] == prevMsgSender, "Caller is not included in the `ERC721VaultFactory`'s whitelist");
        
        return 0x1626ba7e; // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    }
}