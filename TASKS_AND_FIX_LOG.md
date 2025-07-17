# 今後のタスク・修正手順・調査メモ

## 1. Stimulusコントローラ（group_switcher）MIME typeエラー対応
- [x] register名・import名・ファイル名を`group_switcher`に統一
- [x] view側のdata-controller属性も`group_switcher`に統一（grepで未検出）
- [x] アセット再ビルド・サーバ再起動
- [ ] ServiceWorker・ブラウザキャッシュのクリア
- [ ] それでも解消しない場合、Turboキャッシュやregister部分の一時コメントアウトで切り分け
- [ ] 他のコントローラ名との衝突・importmapのパス解決も再確認

## 2. グループ作成UI・E2Eテスト
- [x] /group/newページの削除
- [x] サイドバー/パネル経由のグループ作成UIの動作確認
- [ ] group_switcherコントローラのエラー解消後、E2Eテストでグループ作成・切り替えの自動検証

## 3. その他・今後の改善
- [ ] Docker/Nginx等のリバースプロキシ設定で/assets配下の配信状況も確認
- [ ] 本番環境での挙動も念のため確認
- [ ] READMEや開発手順ドキュメントの整備

---

### 調査メモ
- group_switcher_controller.js自体はビルド・出力OK
- 他のStimulusコントローラは正常動作
- 404やtext/html返却はルーティング・キャッシュ・命名不一致が主な原因
- サイドバーUI自体は表示されている

---

**優先度高:**
1. group_switcherのMIME typeエラー根絶
2. グループ作成・切り替えのE2E自動テスト
3. 開発・運用ドキュメントの整備 
