// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts@4.8.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.8.0/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.8.0/utils/Counters.sol";
import "@openzeppelin/contracts@4.8.0/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts@4.8.0/utils/Base64.sol";

interface WeatherInfo {
    function getCurrentConditions(bytes32 requestId_) external view returns (bytes memory);
    function requestId() external view returns (bytes32);
}

/// @title 天気情報で変化する NFT
/// @dev Custom Logic を使う
contract DynamicWeatherNFT is ERC721, ERC721URIStorage, Ownable, AutomationCompatible {
    /// @dev AutoWeatherInfo コントラクトへクエリするための変数
    WeatherInfo public weatherInfo;

    /// @dev Counters ライブラリの全 Function を構造体 Counter 型に付与
    using Counters for Counters.Counter;

    /// @dev 付与した Counter 型の変数を定義
    Counters.Counter private _tokenIdCounter;

    /// @dev memtaData の更新回数のカウンター用変数を定義
    Counters.Counter private _updatedNFTCounter;

    /// @dev metaData 更新回数の上限値
    uint public maxUpdateCount = 3;
    uint public curUpdateCount = _updatedNFTCounter.current(); // カウンターは 0 始まり

    /// @dev NFTmint 時の metaFile 初期設定
    string public startFile = "ipfs://bafkreihkc5vzdajtp4h6vafrzmld6spb2mbotscs6gjvanwowznyfbc6ly";

    /// @dev URI 更新時に記録する
    event UpdateTokenURI(address indexed sender, uint256 indexed tokenId, string uri);

    /// @dev 前回の更新時間を記録する変数
    uint public lastTimeStamp;

    /// @dev 更新間隔を決める変数
    uint public interval;

    /// @dev AutoWeatherInfo から取得する requestId を保持するための状態変数
    bytes32 public latestRequestId;

    /// @dev 現在の天気情報を記録する構造体
    struct CurrentConditionsResult {
        uint256 timestamp;
        uint24 precipitationPast12Hours;
        uint24 precipitationPast24Hours;
        uint24 precipitationPastHour;
        uint24 pressure;
        int16 temperature;
        uint16 windDirectionDegrees;
        uint16 windSpeed;
        uint8 precipitationType;
        uint8 relativeHumidity;
        uint8 uvIndex;
        uint8 weatherIcon;
    }
    // Maps
    mapping(bytes32 => CurrentConditionsResult) public requestIdCurrentConditionsResult;

    constructor(uint interval_, address weatherInfo_) ERC721("DynamicWeatherNFT", "DWN") {
        interval = interval_;
        lastTimeStamp = block.timestamp;
        weatherInfo = WeatherInfo(weatherInfo_);
    }

    /// @dev checkUpkeep() に渡す checkData(bytes 型) を取得
    function getCheckData(uint tokenId_) public pure returns (bytes memory) {
        return abi.encode(tokenId_);
    }

    /// @dev metaData 更新回数のカウンターリセット
    function resetUpdateCount() public {
        _updatedNFTCounter.reset();
        curUpdateCount = _updatedNFTCounter.current();
    }

    /// @dev 最新の requestId の取得
    function getLatestRequestId() public view returns (bytes32) {
        return weatherInfo.requestId();
    }

    /// @dev 天気情報の取得
    function getWeatherInfo(bytes32 requestId_) public view returns (CurrentConditionsResult memory) {
        bytes memory conditionEncoded = weatherInfo.getCurrentConditions(requestId_);
        CurrentConditionsResult memory condition = abi.decode(conditionEncoded, (CurrentConditionsResult));
        return condition;
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

        // AutoWeatherInfo から最新の requestId を取得して保持
        bytes32 weatherInfoRequestId = getLatestRequestId();

        // 以下条件を満たした場合に performUpkeep を実行する
        // 1. 設定している更新間隔以上の時間が経過していること
        // 2. metaData の更新回数が上限値以下であること
        // 3. AutoWeatherInfo から取得した requestId が latestRequestId が同じでないこと（同じ場合は無駄なのでスキップ）
        // 4. AutoWeatherInfo から取得した天気情報データが登録されていること（condition.timestamp）
        if ((block.timestamp - lastTimeStamp) >= interval
            && curUpdateCount < maxUpdateCount
            && weatherInfoRequestId != latestRequestId
        ) {
            bytes memory conditionEncoded = weatherInfo.getCurrentConditions(weatherInfoRequestId);
            CurrentConditionsResult memory condition = abi.decode(conditionEncoded, (CurrentConditionsResult));

            if (condition.timestamp != 0) {
                // return 値をセット
                upkeepNeeded = true;
                performData = abi.encode(targetId, weatherInfoRequestId, condition);
            } else {
                // return 値をセット
                upkeepNeeded = false;
                performData = '';
            }
        } else {
            // return 値をセット
            upkeepNeeded = false;
            performData = '';
        }
    }

    /// @dev performData には targetId, weatherInfoRequestId, condition が入っている
    function performUpkeep(bytes calldata performData) external {
        (
            uint targetId,
            bytes32 weatherInfoRequestId,
            CurrentConditionsResult memory condition
        ) = abi.decode(performData, (uint, bytes32, CurrentConditionsResult));

        // tokenId の存在チェック
        require(_exists(targetId), "Non-existent tokenId");

        // checkUpKeep で行った条件で再バリデーション
        if ((block.timestamp - lastTimeStamp) >= interval
            && curUpdateCount < maxUpdateCount
            && weatherInfoRequestId != latestRequestId
            && condition.timestamp != 0
        ) {
            // 得られた天気情報を登録
            storeCurrentConditionsResult(weatherInfoRequestId, abi.encode(condition));
            // このコントラクトで管理している latestRequestId を更新
            latestRequestId = weatherInfoRequestId;
            // lastTimeStamp ｗ現在のタイムスタンプに更新
            lastTimeStamp = block.timestamp;
            // TODO: NFT を更新
            _updateNFT(targetId, weatherInfoRequestId);
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
    }

    /// @dev tokenURI を変更し、Event 発行
    function _updateNFT(uint _targetId, bytes32 _requestId) internal {
        // metadata を生成
        string memory uri = generateMetaData(_targetId, _requestId);
        // tokenId を変更
        _setTokenURI(_targetId, uri);
        // NFT の update 回数を increment
        _updatedNFTCounter.increment();
        // NFT の update 回数を更新
        curUpdateCount = _updatedNFTCounter.current();
        // Event 発行
        emit UpdateTokenURI(msg.sender, _targetId, uri);
    }

    /// @dev metadata を生成する
    function generateMetaData(uint _targetId, bytes32 _requestId) public view returns (string memory) {
        CurrentConditionsResult memory condition = requestIdCurrentConditionsResult[_requestId];

        // struct CurrentConditionsResult {
        //     uint256 timestamp;
        //     uint24 precipitationPast12Hours;
        //     uint24 precipitationPast24Hours;
        //     uint24 precipitationPastHour;
        //     uint24 pressure;
        //     int16 temperature;
        //     uint16 windDirectionDegrees;
        //     uint16 windSpeed;
        //     uint8 precipitationType;
        //     uint8 relativeHumidity;
        //     uint8 uvIndex;
        //     uint8 weatherIcon;
        // }

        // 気温は int16 でマイナスがあり得るため、string 型に変換するための対応
        // uint 系の型は、string 型に変換可能だが、int 系の型は変換できないので工夫が必要
        string memory sTemp;
        // マイナスの気温だったら・・・
        if (condition.temperature < 0) {
            uint16 uTemp = uint16(-condition.temperature);
            sTemp = string.concat('-', Strings.toString(uTemp));
        } else {
            // 0 度以上の気温だったらそのまま string 型に型変換できる
            sTemp = Strings.toString(uint16(condition.temperature));
        }

        bytes memory metaData = abi.encodePacked(
            '{',
            '"name": "DynamicWeatherNFT # ',
            Strings.toString(_targetId),
            '",',
            '"description": "Dynamic Weather NFT!"',
            ',',
            '"image": "',
            getImageURI(condition.precipitationType),
            '",',
            '"attributes": [',
                '{',
                '"trait_type": "timestamp",',
                '"value": ',
                Strings.toString(condition.timestamp),
                '},'
                '{',
                '"trait_type": "pressure",',
                '"value": ',
                Strings.toString(condition.pressure),
                '},'
                '{',
                '"trait_type": "temperature",',
                '"value": ',
                sTemp,
                '},'
                '{',
                '"trait_type": "windSpeed",',
                '"value": ',
                Strings.toString(condition.windSpeed),
                '}'
            ']'
            '}'
        );
 
        string memory uri = string.concat("data:application/json;base64,",Base64.encode(metaData));
        return uri;
    }

    /// @dev imageURI の取得
    function getImageURI(uint8 precipitationType_) public pure returns (string memory) {
        string memory baseURI = "ipfs://bafybeiemg4yvdhl27lsctiae7yui5weu2jgvs3gmxr7w4v4yd6gqf7pq2q";
        return string.concat(baseURI, '/image', Strings.toString(precipitationType_), '.jpg');
    }

    /// @dev 天気情報を登録
    function storeCurrentConditionsResult(bytes32 _requestId, bytes memory _currentConditionsResult) private {
        CurrentConditionsResult memory result = abi.decode(_currentConditionsResult, (CurrentConditionsResult));
        requestIdCurrentConditionsResult[_requestId] = result;
    }

    /// @dev 以下は全ての override 重複の整理
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
