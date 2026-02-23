# Subtitle Markdown Editor (Workflow Integration Plugin)

DaVinci Resolve のタイムライン上の字幕を Markdown 形式で編集できるプラグインです。

## 特徴

- **Markdown 編集**: SRT よりも読み書きしやすい Markdown 形式で字幕を編集できます。
- **一括反映**: エディタ上の変更をワンクリックでタイムラインに書き戻します。
- **自動同期**: 書き戻し時に古い字幕トラックを自動的にクリアし、タイムラインの先頭（01:00:00:00）へ正確に再配置します。

## 使い方

1.  DaVinci Resolve を開き、本プラグインが `Workspace > Workflow Integration > Subtitle Markdown Editor` に表示されていることを確認します。
2.  「Load Subtitles」ボタンを押し、現在のタイムラインから字幕を読み込みます。
3.  表示された Markdown エディタでテキストを編集します。
    - `## [HH:MM:SS.mmm]` という形式が見出しとして扱われます。
4.  「Apply & Sync」ボタンを押し、変更をタイムラインに反映させます。
    - **注意**: 実行時に Subtitle Track 1 の既存クリップは削除され、新しい内容に置き換わります。

## 技術スタック

- **Electron**: UI と Resolve API へのブリッジ。
- **WorkflowIntegration.node**: DaVinci Resolve 提供の Workflow Integration SDK。
- **純粋な JS 実装**: `DeleteClips` と `AppendToTimeline` を組み合わせた高精度な配置ロジック。
- **Vite + TypeScript ビルド**: Resolve の厳しいサンドボックス制限やドライブ間シンボリックリンク不可の問題を回避するため、ソースコードを直接 Resolve のディレクトリにビルド・出力するモダンなデプロイ環境を備えています。

## 開発・デプロイ方法

DaVinci Resolve のプラグイン格納フォルダへシンボリックリンク（や同一ドライブ外のジャンクション）を張った状態だと Workflow Integration プラグインが正常に動作しない（読み込まれない・APIが呼べない等の権限エラーが起きる）仕様となっています。

これを回避するため、本プラグインでは Vite のビルドプロセスを利用して、直接 Resolve のプラグインフォルダへソースコードをコピー出力するアーキテクチャを採用しています。

1. Node.js がインストールされていることを確認します。
2. コマンドプロンプト等でこのプラグインのディレクトリ（`src/Workflow_Integration/SubtitleMarkdownEditor/`）を開きます。
3. パッケージをインストールします。
   ```bash
   npm install
   ```
4. ビルドを実行します。これにより、成果物が直接 DaVinci Resolve のプラグイン格納フォルダ (`C:\ProgramData\Blackmagic Design\...`) へデプロイされます。
   ```bash
   npm run build
   ```
   ※開発中は `npm run dev` と打つと、ファイルの変更を検知して自動でビルド＆デプロイが行われます。

