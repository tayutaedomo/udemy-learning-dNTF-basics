// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts@4.8.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.8.0/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.8.0/utils/Counters.sol";

/// @title 時間で成長する NFT
/// @dev time-based を使う
contract TimeGrowStagedNFT is ERC721, ERC721URIStorage, Ownable {
    /// @dev Counters ライブラリの全 Function を構造体 Counter 型に付与
    using Counters for Counters.Counter;

    /// @dev 付与した Counter 型の変数を定義
    Counters.Counter private _tokenIdCounter;

    /// @dev stage 設定
    enum Stages { Baby, Child, Youth, Adult, Granpa }

    /// @dev mint 時に設定する成長ステップを定数化
    Stages public constant firstStage = Stages.Baby;

    /// @dev tokenId と現ステージをマッピングする変数を定義
    mapping(uint => Stages) public tokenStage;

    /// @dev NFT mint 時は特定の URI を指定する
    string public startFile = "metadata1.json";

    /// @dev URI 更新時に記録する
    event UpdateTokenURI(address indexed sender, uint256 indexed tokenId, string uri);

    constructor() ERC721("TimeGrowStagedNFT", "TGS") {}

    /// @dev metadata 用の baseURI を設定する
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://bafybeichxrebqguwjqfyqurnwg5q7iarzi53p64gda74tgpg2uridnafva/";
    }

    /// @dev 以下は全ての override 重複の整理
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
