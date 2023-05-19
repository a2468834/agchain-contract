// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@transmissions11/solmate/src/tokens/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721TokenVault.sol";
import "./ERC721VaultFactory.sol";
import "../nft/CO2eCertificateNFT.sol";

contract ERC20TokenCenter is Ownable, ReentrancyGuard, ERC20 {
    /***************************** State veriable *****************************/
    ERC721VaultFactory public erc721VaultFactory;
    CO2eCertificateNFT public co2eCertificateNFT;
    
    /********************************** Event *********************************/
    event ExchangeToERC20(
        address indexed originalNFT,
        uint256 indexed vaultId,
        uint256 ratio,
        uint256 supply
    );
    
    event ExchangeToERC721(
        address indexed issuingNFT,
        uint256 tokenId
    );
    
    event AllowanceRecord(
        address indexed owner,
        address indexed spender,
        uint256 prevAmount,
        uint256 currAmount
    );
    
    event TransferByPlatform(
        address indexed from,
        address indexed spender,
        address to,
        uint256 amount
    );
    
    /****************************** Constructor *******************************/
    /**
     * @dev Because all the "Carbon Credit FT" are defined at "kilogram" in
     *      this contract, it is okay to use `decimals` = 0 in the constructor.
     *      If so, the frontend wallet will display token balances as "kilogram"
     *      to the users. Besides, developer could choose `decimals` = 3 for
     *      displaying token balances as "ton".
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol, decimals) {}
    
    /************************** Public read function **************************/
    function callERC1271isValidSignature(
        bytes32 _hash,
        bytes calldata _signature
    ) external view {
        try erc721VaultFactory.isValidSignature(_hash, _signature) returns (bytes4 result) {
            require(result == 0x1626ba7e, "Invalid ERC-1271 signature");
        } catch {
            revert("Failed to call `ERC721VaultFactory`'s `isValidSignature()`");
        }
    }
    
    /************************** `onlyOwner` function **************************/
    function setERC721VaultFactory(
        address newERC721VaultFactory
    ) external onlyOwner returns (bool) {
        require(newERC721VaultFactory != address(erc721VaultFactory), "Cannot set the same address twice");
        erc721VaultFactory = ERC721VaultFactory(newERC721VaultFactory);
        return true;
    }
    
    function setCO2eCertificateNFT(
        address newCO2eCertificateNFT
    ) external onlyOwner returns (bool) {
        require(newCO2eCertificateNFT != address(co2eCertificateNFT), "Cannot set the same address twice");
        co2eCertificateNFT = CO2eCertificateNFT(newCO2eCertificateNFT);
        return true;
    }
    
    function mintToken(
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        _mint(to, amount);
        return true;
    }
    
    function burnToken(
        address from,
        uint256 amount
    ) external returns (bool) {
        // Called by `CO2eCertificateNFT` or `onlyOwner`
        if ((msg.sender != owner()) && (msg.sender != address(co2eCertificateNFT))) {
            revert("Caller is not allowed to invoke this function");
        }
        
        _burn(from, amount);
        return true;
    }
    
    /************************* Public write function **************************/
    /**
     * @dev Exchange ERC721 token to ERC20 tokens
     * 
     * This function is meant to be called by `TokenVault` created by
     * `ERC721VaultFactory`, otherwise it will revert.
     * 
     * @param creator `TokenVault`'s creator who is the receiver of new Carbon Credit FTs
     * @param vaultId `TokenVault`'s identifier in the `ERC721VaultFactory`
     * @param originalNFT The underlying NFT contract belongs to `TokenVault`
     * @param supply Amount of Carbon Credit FTs which will be minted
     * @param ratio Conversion ratio of NFT's `weight` to Carbon Credit FT
     */
    function exchangeToken(
        address creator,
        uint256 vaultId,
        address originalNFT,
        uint256 supply,
        uint256 ratio
    ) external returns (bool) {
        // Check validity of the caller (a contract created by `ERC721VaultFactory`)
        address tokenVaultAddress = msg.sender;
        bytes memory _signature = abi.encode(tokenVaultAddress, vaultId);
        bytes32 _hash = keccak256(_signature);
        this.callERC1271isValidSignature(_hash, _signature);
        
        // Mint new Carbon Credit FTs according to the argument `supply`
        _mint(creator, supply);
        emit ExchangeToERC20(originalNFT, vaultId, ratio, supply);
        
        return true;
    }
    
    /**
     * @dev Exchange ERC20 tokens to ERC721 token
     * 
     * This function can be called by anyone who owns at least `minSwapAmount`
     * amount of Carbon Credit FTs.
     * 
     * @param receiver Address of receiver who owns the new minted CO2e Certificate NFT
     * @param amount Amount of Carbon Credit FTs that receiver wants to exchange
     */
    function exchangeToken(
        address receiver,
        uint256 amount
    ) external nonReentrant returns (bool) {
        // Transfer `ERC20TokenCenter` tokens to this contract
        require(
            allowance[msg.sender][address(this)] >= amount,
            "Carbon Credit FT allowance is not enough for now"
        );
        TransferFromHelper.safeTransferFrom(
            address(this),
            msg.sender,
            address(this),
            amount
        );
        
        // Grant transferring FT permission to `CO2eCertificateNFT`
        this.approve(address(co2eCertificateNFT), amount);
        
        // Mint a new NFT
        uint256 tokenId = co2eCertificateNFT.mintToken(
            receiver,
            amount
        );
        emit ExchangeToERC721(address(co2eCertificateNFT), tokenId);
        return true;
    }
    
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        address owner = msg.sender;
        require(owner != address(0), "Cannot approve from the zero address");
        require(spender != address(0), "Cannot approve to the zero address");
        
        uint256 oldAmount = allowance[owner][spender];
        uint256 newAmount = oldAmount + addedValue;
        require(approve(spender, newAmount), "Failed to call `approve()`");
        
        emit AllowanceRecord(
            owner,
            spender,
            oldAmount,
            newAmount
        );
        
        return true;
    }
    
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        address owner = msg.sender;
        require(owner != address(0), "Cannot approve from the zero address");
        require(spender != address(0), "Cannot approve to the zero address");
        
        uint256 oldAmount = allowance[owner][spender];
        uint256 newAmount;
        require(oldAmount >= subtractedValue, "Try to decrease allowance below zero");
        unchecked {
            newAmount = oldAmount - subtractedValue;
        }
        require(approve(spender, newAmount), "Failed to call `approve()`");
        
        emit AllowanceRecord(
            owner,
            spender,
            oldAmount, 
            newAmount
        );
        
        return true;
    }
    
    /************************** Overriding function ***************************/
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        super.transferFrom(from, to, amount);
        
        if (msg.sender == owner()) {
            emit TransferByPlatform(from, msg.sender, to, amount);
        }
        else {
            // Do nothing
        }
        
        return true;
    }
}