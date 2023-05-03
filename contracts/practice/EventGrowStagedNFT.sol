// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts@4.8.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.8.0/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.8.0/utils/Counters.sol";
import "@openzeppelin/contracts@4.8.0/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

/// @title 時間で成長する NFT
/// @dev Custom Logic を使う
contract EventGrowStagedNFT is ERC721, ERC721URIStorage, Ownable, AutomationCompatible {
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

    /// @dev 前回の更新時間を記録する変数
    uint public lastTimeStamp;

    /// @dev 更新間隔を決める変数
    uint public interval;

    constructor(uint interval_) ERC721("EventGrowStagedNFT", "EGS") {
        interval = interval_;
        lastTimeStamp = block.timestamp;
    }

    /// @dev checkUpkeep() に渡す checkData(bytes 型) を取得
    function getCheckData(uint tokenId_) public pure returns (bytes memory) {
        return abi.encode(tokenId_);
    }

    /// @dev checkData には、getCheckData() で得られた Bytes 型を指定
    function checkUpkeep(bytes calldata checkData)
        external 
        view 
        // cannotExecute // 実際に使用する場合はコメントアウトを外してオンチェーンでのみの実行にする
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // decode して対象の tokenId を取得
        uint targetId = abi.decode(checkData, (uint));
        // tokenId の存在チェック
        require(_exists(targetId), "Non-existent tokenId");
        // 次の Stage を格納する uint 型変数
        uint nextStage = uint(tokenStage[targetId]) + 1;

        if ((block.timestamp - lastTimeStamp) >= interval
            && nextStage <= uint(type(Stages).max)
        ) {
            // return 値をセット
            upkeepNeeded = true;
            performData = abi.encode(targetId, nextStage);
        } else {
            // return 値をセット
            upkeepNeeded = false;
            performData = '';
        }
    }

    function performUpkeep(bytes calldata performData) external {
        (uint targetId, uint nextStage) = abi.decode(performData, (uint, uint));

        // tokenId の存在チェック
        require(_exists(targetId), "Non-existent tokenId");
        // 次の Stage を格納する uint 型変数
        uint vNextStage = uint(tokenStage[targetId]) + 1;

        if ((block.timestamp - lastTimeStamp) >= interval
            && nextStage == vNextStage
            && nextStage <= uint(type(Stages).max)
        ) {
            lastTimeStamp = block.timestamp;
            _growNFT(targetId, nextStage);
        }
    }

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
    function _growNFT(uint targetId_, uint nextStage_) internal {
        // metaFile の決定
        string memory metaFile = string.concat("metadata", Strings.toString(nextStage_ + 1), ".json");
        // tokenURI を変更
        _setTokenURI(targetId_, metaFile);
        // Stage の登録変更
        tokenStage[targetId_] = Stages(nextStage_);
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
