# elastic-classifier package

Training classifiers for elasticsearch.

You cat generate the percolator queries for classification such as:

```json
{
  "_index": "blog",
  "_type": ".percolator",
  "_id": "経済",
  "_version": 1,
  "found": true,
  "_source": {
    "query": {
      "bool": {
        "must": [
          {
            "match": {
              "title": {
                "query": "時事通信 株式 東京 ny 外為 株 日経 sankeibiz サーチナ bloomberg 前場 ロイター impress watch bw オートックワン ダウ 東証 中国 円 急伸 スズキ 前半 ドル レスポンス 米 市場 利益 新型 企業 サマリー 東芝 寄り付き エコノミックニュース フランクフルトモーターショー 株価 終値 住宅 後場 mrj 電力 朝日新聞 毎日新聞 wire ストップ高 銀 ビジネス 上方 好感 vw ロンドン aviation 事業 中間 デジタル 欧州 トヨタ 海外 業務 ローソン スリーエフ ビル 子会社 monoist ファミマ 三菱 工場 新報 三菱地所 週 ナスダック 三井 アウトランダー 商品 ユーロ 国産 zuu マツダ インド phev 自動 駅前 見通し 自動車 online 安 始 景気 ロボット エンジン シャープ 日本一 インドネシア 経済 ブラジル 新規 読売新聞 産経新聞 法人 月",
                "operator": "or",
                "minimum_should_match": "2%"
              }
            }
          },
          {
            "match": {
              "contents": {
                "query": "市場 株式 株価 指数 日経 了 株 相場 円 終値 ドル 為替 中国 経済 証券 銘柄 東証 利益 大手 自動車 外国 事業 frb 原油 ダウ topix 下げ 金融 米 買い 値動き 工業 景気 見通し 出来高 ブルームバーグ 東京 子会社 議長 半面 上海 急伸 ロイター フィッシャー 上げ幅 四半期 ユーロ ニューヨーク 月利 ナスダック bloomberg 原文 gdp 石油 銀行 エディター 先物 三菱 上方 トヨタ 業績 値 材料 businesswire ホールディングス 当局 新型 水準 制度 保険 スズキ 編 ワイヤ bizw 連邦 av 全面 好感 指標 watch 見方 戦略 ビジネス 金利 宮川 car 子平 同社 工場 反動 注 net 政策 会社 記事 企業 理事 動き 寄り付き 時事",
                "operator": "or",
                "minimum_should_match": "2%"
              }
            }
          }
        ]
      }
    },
    "classification": "tags"
  }
}
```


## Settings

### Host
The host of the elasticsearch.
Default to 'http://localhost:9200'

### Index
The name of the index.
default to 'blog'

### Doc Type
The type of the document.
Default to 'posts'

### Classification Field
The field of the category.
Default to 'tags'

### Query Match Fields
The fields of the match document.
Default to ['title', 'contents']

### Query Maximum Terms
Default to 100

### Query Minimum Should Match
Default to '2%'

### Stopwords
Default to []

## Commands
### Elastic Classifier: Generate Percolator Queries
### Elastic Classifier: Get Percolator Query
### Elastic Classifier: Evaluate Percolator Queries
### Elastic Classifier: Find Misclassifications
### Elastic Classifier: Delete Percolator Query
