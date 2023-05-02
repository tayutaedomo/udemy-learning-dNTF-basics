// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts@4.8.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.8.0/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.8.0/utils/Counters.sol";
import "@openzeppelin/contracts@4.8.0/utils/Strings.sol";

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

    /// @dev NFT を mint、初期 stage と URI は固定
    function ntfMint() public onlyOwner {
        // tokenIｄ を 1 増やす、tokenId は 1 から始まる
        _tokenIdCounter.increment();
        // 現時点の tokenId を取得
        uint256 tokenId = _tokenIdCounter.current();
        // NFT mint
        _safeMint(msg.sender, tokenId);
        // tokenURI を設定
        _setTokenURI(tokenId, startFile);
        // Event 発行
        emit UpdateTokenURI(msg.sender, tokenId, startFile);
        // tokenId 毎に成長ステップを記録
        tokenStage[tokenId] = firstStage;
    }

    /// @dev 成長できる余地があれば tokenURI を変更し Event を発行
    function growNFT(uint targetId_) public {
        // 今の stage
        Stages curStage = tokenStage[targetId_];
        // 次の stage を設定（整数値に型変換）
        uint nextStage = uint(curStage) + 1;
        // Enum で指定している範囲を超えなければ tokenURI を変更し Event を発行
        require(nextStage <= uint(type(Stages).max), "Over stage");
        // metaFile の決定
        string memory metaFile = string.concat("metadata", Strings.toString(nextStage + 1), ".json");
        // tokenURI を変更
        _setTokenURI(targetId_, metaFile);
        // Stage の登録変更
        tokenStage[targetId_] = Stages(nextStage);
        // Event 発行
        emit UpdateTokenURI(msg.sender, targetId_, metaFile);
    }

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
