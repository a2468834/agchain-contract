// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./ERC20TokenCenter.sol";
import "../nft/CarbonCreditNFT.sol";

contract ERC721TokenVault {
    /******************************** Constant ********************************/
    // Address of Carbon Credit FT contract
    ERC20TokenCenter public immutable erc20TokenCenter;
    
    // Address of the underlying NFT contract
    CarbonCreditNFT  public immutable underlyingToken;
    
    // `tokenId` of the underlying NFT
    uint256 public immutable underlyingTokenId;
    
    // Address who creates this NFT vault
    address public immutable creator;
    
    // `TokenVault`'s identifier in the `ERC721VaultFactory`'s mapping `vaults`
    uint256 public immutable vaultId;
    
    // Conversion ratio of NFT's `weight` to Carbon Credit FT
    uint16  public immutable ratio;
    
    // Carbon credit `weight` of the underlying NFT
    uint64  public immutable weight;
    
    // Amount of new minted Carbon Credit FT
    uint256 public immutable supply;
    
    /****************************** Constructor *******************************/
    constructor(
        ERC20TokenCenter _erc20TokenCenter,
        CarbonCreditNFT  _underlyingToken,
        uint256 _tokenId,
        address _creator,
        uint256 _vaultId
    ) {
        // Initialize some constants
        erc20TokenCenter  = _erc20TokenCenter;
        underlyingToken   = _underlyingToken;
        underlyingTokenId = _tokenId;
        creator           = _creator;
        vaultId           = _vaultId;
        
        // Check if the ownership of NFT has been passed to this contract
        require(underlyingToken.ownerOf(underlyingTokenId) == address(this), "New `TokenVault` has not owned the NFT");
        
        // Calaculate the amount of new Carbon Credit FT which will be minted
        CarbonCreditNFT.TokenInfo memory tokenInfo;
        
        try underlyingToken.getTokenInfo(underlyingTokenId) returns (CarbonCreditNFT.TokenInfo memory _tokenInfo) {
            tokenInfo = _tokenInfo;
        } catch {
            revert("Failed to get `TokenInfo` from Carbon Credit NFT contract");
        }
        
        try underlyingToken.getRatio(tokenInfo.issueById) returns (uint16 _ratio) {
            ratio  = _ratio;
            weight = tokenInfo.weight;
            supply = uint256(weight) * uint256(ratio);
        } catch {
            revert("Failed to get `ratio` from Carbon Credit NFT contract");
        }
        
        // Call `ERC20TokenCenter.exchangeToken()` to mint new Carbon Credit FT
        bool result = erc20TokenCenter.exchangeToken(
            creator,
            vaultId,
            address(underlyingToken),
            supply,
            ratio
        );
        require(result, "Failed to mint new Carbon Credit FTs");
    }
    
    /************************** Overriding function ***************************/
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        // Do nothing because this vault is meant to lock NFT forever.
        
        if ((operator == operator) || (from == from) || (tokenId == tokenId) || (keccak256(data) == keccak256(data))) {
            // Dummy expresions using for disabling compiler unused function parameter warnings
        }
        
        return IERC721Receiver.onERC721Received.selector;
    }
}