// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IERC4906.sol";

contract CarbonCreditNFT is Ownable, IERC4906, ERC721 {
    /******************************* Structure ********************************/
    struct NewTokenData {
        string certId;     // 證書 ID（至多三十二位元組）
        uint256 sourceId;  // 證書來源 ID
        uint256 issueById; // 簽發機構 ID
        uint64  weight;    // 碳權當量（公噸）
    }
    
    struct TokenInfo {
        string certId;     // 證書 ID（至多三十二位元組）
        uint256 sourceId;  // 證書來源 ID（需再查詢 `getSourceList()`）
        uint256 issueById; // 簽發機構 ID（需再查詢 `getIssueByList()`）
        uint64 weight;     // 碳權當量（公噸）
        uint256 date;      // 代幣鑄造時間戳記
    }
    
    struct TokenInfoLiterally {
        string certId;  // 證書 ID（至多三十二位元組）
        string source;  // 證書來源字串（至多三十二位元組）
        string issueBy; // 簽發機構字串（至多三十位元組）
        uint64 weight;  // 碳權當量（公噸）
        uint256 date;   // 代幣鑄造時間戳記
    }
    
    struct TokenData {
        uint256 sourceId;
        uint256 issueById;
        bytes32 certId;
        uint192 date;
        uint64  weight;
    }
    
    struct CertSource {
        bytes32 source;
    }
    
    struct CertIssueBy {
        bytes30 issueBy; // 簽發機構字串（至多三十位元組）
        uint16  ratio; // `weight` * `ratio` = Carbon Credit FTs `supply` amount
    }
    
    /***************************** State veriable *****************************/
    uint256 public maxSourceId;
    uint256 public maxIssueById;
    uint256 public currTokenId;
    
    mapping(uint256 => TokenData) private _tokenURIs; // `tokenId` => TokenData
    mapping(uint256 => CertSource) private _sourceMaps; // `sourceId` => CertSource
    mapping(uint256 => CertIssueBy) private _issueByMaps; // `issueById` => CertIssueBy
    
    /****************************** Constructor *******************************/
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}
    
    /************************** Public read function **************************/
    function getSourceList() external view returns (string[] memory){
        string[] memory sourceList = new string[](maxSourceId);
        bytes32 ith_source;
        
        for (uint256 i = 0; i < maxSourceId;) {
            ith_source = _sourceMaps[i].source;
            sourceList[i] = string(bytes.concat(ith_source));
            unchecked {i++;}
        }
        
        return sourceList;
    }
    
    function getIssueByList() external view returns (string[] memory){
        string[] memory issueByList = new string[](maxIssueById);
        bytes30 ith_issueBy;
        
        for (uint256 i = 0; i < maxIssueById;) {
            ith_issueBy = _issueByMaps[i].issueBy;
            issueByList[i] = string(bytes.concat(ith_issueBy));
            unchecked {i++;}
        }
        
        return issueByList;
    }
    
    function getTokenInfo(
        uint256 tokenId
    ) external view returns (TokenInfo memory){
        require(ERC721._exists(tokenId), "Cannot get non-existent token");
        
        TokenData memory tokenData = _tokenURIs[tokenId];
        
        return TokenInfo(
            string(bytes.concat(tokenData.certId)),
            tokenData.sourceId,
            tokenData.issueById,
            tokenData.weight,
            (((block.timestamp>>192)<<192) + uint256(tokenData.date))
        );
    }
    
    function getTokenInfoLiterally(
        uint256 tokenId
    ) external view returns (TokenInfoLiterally memory) {
        require(ERC721._exists(tokenId), "Cannot get non-existent token");
        
        TokenData memory tokenData = _tokenURIs[tokenId];
        
        return TokenInfoLiterally(
            string(bytes.concat(tokenData.certId)),
            string(bytes.concat(_sourceMaps[tokenData.sourceId].source)),
            string(bytes.concat(_issueByMaps[tokenData.issueById].issueBy)),
            tokenData.weight,
            (((block.timestamp>>192)<<192) + uint256(tokenData.date))
        );
    }
    
    function getRatio(uint256 issueById) external view returns (uint16) {
        require(issueById < maxIssueById, "Cannot get non-existent `issueBy`");
        
        CertIssueBy storage slot = _issueByMaps[issueById];
        require((slot.issueBy) != bytes30(0), "Cannot get non-existent `issueBy`");
        
        return slot.ratio;
    }
    
    /************************** `onlyOwner` function **************************/
    function addSource(
        string calldata source
    ) external onlyOwner returns (bool) {
        require(bytes(source).length != 0, "Forbid empty `source`");
        require(bytes(source).length < 33, "The length of `source` <= 32 bytes");
        
        _sourceMaps[maxSourceId] = CertSource(bytes32(abi.encodePacked(source)));
        maxSourceId++;
        
        return true;
    }
    
    function delSource(uint256 sourceId) external onlyOwner returns (bool) {
        require(sourceId < maxSourceId, "Cannot delete non-existent `source`");
        _sourceMaps[sourceId] = CertSource(bytes32(0));
        return true;
    }
    
    function addIssueBy(
        string calldata issueBy,
        uint16 ratio
    ) external onlyOwner returns (bool) {
        require(bytes(issueBy).length != 0, "Forbid empty `issueBy`");
        require(bytes(issueBy).length < 31, "The length of `issueBy` <= 30 bytes");
        require(ratio != 0, "Conversion `ratio` must be non-zero");
        
        _issueByMaps[maxIssueById] = CertIssueBy(bytes30(abi.encodePacked(issueBy)), ratio);
        maxIssueById++;
        
        return true;
    }
    
    function delIssueBy(uint256 issueById) external onlyOwner returns (bool) {
        require(issueById < maxIssueById, "Cannot delete non-existent `issueBy`");
        _issueByMaps[issueById] = CertIssueBy(bytes30(0), 0);
        return true;
    }
    
    function addOrSetRatio(
        uint256 issueById,
        uint16 ratio
    ) external onlyOwner returns (bool) {
        require(issueById < maxIssueById, "Cannot modify non-existent `issueBy`");
        require(ratio != 0, "Conversion `ratio` must be non-zero");
        
        CertIssueBy storage slot = _issueByMaps[issueById];
        require((slot.issueBy) != bytes30(0), "Cannot modify non-existent `issueBy`");
        slot.ratio = ratio;
        
        return true;
    }
    
    /************************* Public write function **************************/
    function mintToken(
        NewTokenData calldata newTokenData,
        address receiver
    ) external onlyOwner returns (bool) {
        uint256 newTokenId;
        unchecked {
            newTokenId = (currTokenId++);
        }
        
        _safeMint(receiver, newTokenId);
        _setTokenURI(newTokenId, newTokenData);
        
        return true;
    }
    
    // function burnToken(uint256 tokenId) external onlyOwner returns (bool) {
    // /**
    //  * @dev We don't implement this function.
    //  */
    // }
    
    /**************************** Private function ****************************/
    function _constructTokenURI(
        uint256 tokenId
    ) private view returns (string memory) {
        TokenData memory tokenData = _tokenURIs[tokenId];
        
        return string(
            abi.encode(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encode(
                            '{"certId":"',
                            string(bytes.concat(tokenData.certId)),
                            '", "sourceId":"',
                            Strings.toString(tokenData.sourceId),
                            '", "issueById":"',
                            Strings.toString(tokenData.issueById),
                            '", "weight":"',
                            Strings.toString(tokenData.weight),
                            '", "date":"',
                            string.concat(Strings.toString((block.timestamp>>192)), Strings.toString(tokenData.date)),
                            '"}'
                        )
                    )
                )
            )
        );
    }
    
    function _setTokenURI(
        uint256 tokenId,
        NewTokenData calldata newTokenData
    ) private {
        require(ERC721._exists(tokenId), "Cannot set non-existent token");
        require(bytes(newTokenData.certId).length < 33, "The length of `certId` <= 32 bytes");
        
        _tokenURIs[tokenId] = TokenData(
            newTokenData.sourceId,
            newTokenData.issueById,
            bytes32(abi.encodePacked(newTokenData.certId)),
            uint192(block.timestamp), // Higher-order bits are cut off.
            newTokenData.weight
        );
        
        emit MetadataUpdate(tokenId);
    }
    
    /************************** Overriding function ***************************/
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        return _constructTokenURI(tokenId);
    }
}