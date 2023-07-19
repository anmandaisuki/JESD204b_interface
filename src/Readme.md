# JESD204B用インターフェイスHDL

## JESD204B_RX_CON.v
### ポートの説明
* RXUSERDY: gtwizardIPを初期化とかでResetするためにHighにする必要あり。
* RXUSRCLK2: user側のパラレルインターフェイス用のクロック。RXDATAを読むときの同期クロックになる。RXDATAの幅とINT_Datawidth、RXUSRCLKによって決まる。[(GTH,table4-53参照)](http://padley.rice.edu/cms/OH_GE21/UG476_7Series_Transceivers.pdf)
* RXUSRCLK : レシーバのPCSに供給するクロック。F=LineRate/Int_DataWidthで供給周波数を求めることができる。
    * ex) LineRate=8Gbpsのとき、DataWidthは64bitなので、8000/64=125Mhzのクロックを供給する必要がある。Int_DataWidthは2byteか4byteで6.6Gbpsのときは必ず4byte。
[(GTH,詳しくはUG476、p297みて)](http://padley.rice.edu/cms/OH_GE21/UG476_7Series_Transceivers.pdf)
[(GTY,p304)](https://docs.xilinx.com/v/u/ja-JP/ug578-ultrascale-gty-transceivers)

* clk_freerun: gtwizardIPに入力するクロック。Resetシーケンスとかで必要なので、最初に必要。最大周波数はFupper(デバイスとその使用するPLL(CPLLかQPLL)によって決まっており、ultrascaleなら200MHz)かFrxusrclk2の低い方になる。RXUSRCLK2が125MHzなら125MHzが最大周波数となる。

### gtwiz_usrclk関連


### gtwiz_reset関連
* リセットシーケンス
    *基本はgtwiz_reset_clk_freerun_inを入力 > gtwiz_reset_all_inでリセット で良さそう。gtwiz_reset_rx_pll_and_datapath_in,gtwiz_reset_rx_datapath_inなどもあるが、all_inでまとめて良さそう。

### 供給クロックについて
1. freerun_clk : PLLの初期化とか用クロック。100MHzくらいでいい。Wizard上で設定。
1. gtrefclk00_in: 00-11まである。commonプリミティブ。wizardでtxかrx側のPLLをQPLL0/1に設定してると存在する。(Basic > Transmitter/Receiver > PLL type)
1. gtrefclk0_in/gtrefclk1 : channelプリミティブへの供給クロック。wizardでtxかrx側のPLLをCPLLに設定してると存在する。(Basic > Transmitter/Receiver > PLL type)
1. USRCLK   : PCSの動作クロック。F=LineRate/Int_DataWidth
1. USRCLK2  : User側のパラレルインターフェイスのクロック。gtwiz_userdata_rx_outの同期クロック。
1. 

### トランシーバの基本
* Xilinxのトランシーバはトランシーバクアッドと呼ばれ、1つのトランシーバにつき4チャンネルもつ。
* 各トランシーバはそれぞれPLLをもち、refclkをどこかしらから供給することで動作する。おそらくPLLに供給したrefclkから、シリアルのlinerateに近い周波数を生成し、シリアルのクロックリカバリーしてる。
* 1つのFPGA内に複数のトランシーバーがある。Ultrascale Kintexとかなら最低12個(48ch)ある。
* refclkは基本外部から供給するが、トランシーバ同士でシェアできるため、1つのトランシーバにrefclkを供給すれば、それで事足りる場合もある。
* １つのトランシーバにQPLLが1つ(4チャンネルで共有)と4つのCPLL(各チャンネル)がある。
* common プリミティブ=QPLL, channelプリミティブ=CPLLみたいな感じ。

## vivadoのUltraScale FPGAs Transceivers Wizardについて
* Basic > Transceiver/Receiver のPLLタイプはGTHトランシーバ内のtx/rxへの供給クロックをどのPLLを使って供給するか。tx側とrx側で異なるPLLを選択することもできて、例えば１つのチャネルのtxポートはCPLL(channelプリミティブ),rxポートはQPLL(commonプリミティブ)にすることもできる。

* QPLL0とQPLL1,CPLLは対応周波数が異なるので注意。特に理由はなく、tx/rxで同じ周波数であればQPLLでよい。

* Physical Resources > Channel tableは上記で述べたBasicタブの設定が反映される。Basicタブでtxの供給をCPLLからに設定している場合、Physical Resources画面ではQPLLからREFCLKを持ってくる設定ができない。

* PLL typeで設定したPLLに供給するクロック周波数はBasic > Transceiver/Receiver > Actual Reference Clockになる。 Requested Frequencyを入力してcalcを押すと、Actual Reference Clockの候補が変化する。大体の入力したい周波数をRequested Frequencyに入力してcalcを押す。

* Pyhsical Resources > Channel table > TX/RX REFCLK sourceの選択欄のMGTRECLKというのは、外部端子からのクロック。IBUFDS_GTE3/4というIOプリミティブからの入力。各クアッドトランシーバに2つのMGTREFCLK0と1が存在する。隣接するクアッドトランシーバからクロックを共有できたりするので、MGTREFCLK1 of QuadX0Y1のようにMGTREFCLK1の中でも、どのトランシーバのMGTREFCLK1を使うか選択する必要がある。

* MGTREFCLK0/1はIBUFDS_GTE3/4のポートなので、実際は差動ポートになっている。ただし、生成されたipのポートはgtrefclk00_inのように１つのポートになっている。シミュレーション時は、シングルエンドのクロックを入力すればいいが、implementationするときは、IBUFDS_GTE3/4プリミティブを自分で実装した方がいいかも？それか合成時に自動でポート割当してくれる？

* PLL typeをCPLLにして、クアッドトランシーバのトランシーバを4つ有効化すると、gtrefclk0(CPLL)は各チャンネルに供給するので、4bit幅になる。

### カンマアライメント
* 手動アライメントでトランシーバーに搭載されるbitslideを使っても同じことができる。ただし7seriesのtransceiver wizardでJESD204のプリセットを使用すると、bitslideを有効化できなかったので、7seriesのトランシーバだとbitslideを使った方式はできないかも？
* [p233あたりにカンマ検出時の挙動記載されている。](https://docs.xilinx.com/v/u/ja-JP/ug576-ultrascale-gth-transceivers)

### ややこしいとこメモ
* 8b10bがenableのとき、RX_DATA_WIDTHはRXDATAポートの幅とは一致しない。ポート幅はRX_DATA_WIDTHとかRX_INT_DATAWIDTHとかのコンビネーションによって決定する。[ug576,p302,実際のポート幅は...](https://docs.xilinx.com/v/u/ja-JP/ug578-ultrascale-gty-transceivers)
* RX_INT_DATAWIDTHは0で2byte,１で4byteを表すと書いてあるけど、実際は8b10bデコーダの前後で40bit > 32bitのようにバス幅が変更している。つまりPCS内でバス幅が完全に一致しているわけではない。
* LineRateとPCSの内部バス幅で　RXUSRCLKが決まる。このときのPCSの内部バス幅は8b10bデコード前の値。つまり20とか40とかになる。
* RXDATAとPCSの内部バスの幅でRXUSRCLKとRXUSRCLK2の関係性が決まる。例えばPCSの8b10bデコード後に32bitでRXDATAポートが64bitの場合、64bit出力するにはPCS内で2クロック必要なので、RXUSRCLK = 2 * RXUSRCLK2となる。RXUSRCLK2（RXDATAの出力同期クロック）はRXUSRCLK(PCSの内部クロック)の半分でないといけない。  
* RXOUTCLKはQPLLやCPLLから供給されたREFCLKから生成されるクロックや、CDRによって再生されたクロックなど、ㇳランシーバーchannelプリミティブ内部のクロックを外に出すためのポート。
* トランシーバからユーザーロジックへ入力されるクロックはすべてBUFG_GTを介する。なので、外部からトランシーバのQPLLやCPLLに入力したクロックをユーザー側へ配線したい場合も、BUFG_GTを介してならできるっぽい。GTY/GTHトランシーバとFPGA側との間にBUFG_GTが存在し、クロックは絶対にそこは経由しないといけない。
* インターコネクトの中身はトランシーバのPL側に非同期FIFOみたいなのがあって、書き込み側がRXUSRCLK、読み込み側がRXUSRCLK2みたいな感じ。
* RXOUTCLKはGTYトランシーバ内のどこかしらのクロックを出力できるポート。RXOUTCLKSELでどこから出すか決めれる。PMAのクロックかPCSのクロックかなど。
* RXOUTCLKは複数GTYトランシーバを使用し、トランシーバ同士でタイミングズレの少ないシステムを構築したいときに便利そう。RXOUTCLKの出力がBUFG_GTという低ジッタ、スキューバッファになっており、他のトランシーバやチャネルにクロックを届けやすい。
* RXOUTCLKでPCSのクロックを外に出すとき、USRCLKが元となる。そのチャネルのRXOUTCLKをそのチャネルのUSRCLKにつなぐのは間違い。元となるUSRCLKがなければRXOUTCLKは出力できない。USRCLKが入力されたチェネルのRXOUTCLKを他のチャネルのUSRCLKにつなぐのが正しい接続方法。

## 8b10bデコード時のRXCTRLについて
* rxctrlはout of order検出したときは`RXCTRL3`が`High`になり、`RXCTRL0`と`RXCTRL1`にデコードできなかった残りの2bitを吐き出す。`RXCTRL3`がLowの状態で、`RXCTRL1`がHighの場合、Disparityエラーとなる。
* `RXCTRL0`がHighのとき、RXDATAはK符号である。受信データがK符号を区別したいとき、`RXCTRL0`を見ればいい。
* 例えばクアッドトランシーバの４つのチャネルが有効化され、各チャネルのパラレル側が32bit(RXDATA)の場合、gtwiz_userdata_rx_outは32*4=128bitとなる。wizardが生成する`rxctrl2_out`はすべてのチャネルの`RXCTRL2`は1つにまとめちゃってるので、4つのチャネルを有効化したとき、`rxctrl2_out`は 8 * 4 = 32bitとなる。さらにrxctrl2[0]はRXDATAの1byte目,rxctrl2[1]は2byte目のようになっているので、RXDATAが32bitのときrxctrl2[4-7]は使用されない。そのため分かりづらいけど、32bitで４つのチャネルを有効化したトランシーバの`rxctrl2_out[31:0]`の4-7bit目,12-15bit目,20-23bit目、28-31bit目は使用されない。64bitで４つのチャネルを有効化すると、`rxctrl2_out[31:0]`のすべてのbitが使用される。

### ひっかかりそうなとこ
* GTPOWERGOOD が High にアサートされてから少なくとも250µs経過してから、IBUFDS_GTE3/4からトランシーバへのクロック入力（IBUFDSからの出力）が有効になる。[p39とp64,UG576](https://docs.xilinx.com/v/u/ja-JP/ug576-ultrascale-gth-transceivers)
* 
### 略称とか呼び方
1. gtwizardIP : vivadoのultrascale transceiver wizardで作成できるIPをここではgitwizardIPと呼ぶ.だいたいGTHトランシーバーになると思う。Ultrascale+のGTYや7seriesのGTX,GTPトランシーバでも変更すれば同じようにできるとはず。ただ細々したところで仕様違うから、データシートで確認必要。
1. GTHE3/4 : Ultrascale のGTHトランシーバをGTHE3,Ultrascale+のGTHトランシーバをGTHE4トランシーバと呼ぶ。なのでユーザーガイド内だと、GTHE3/4という用語が使われてる。
1. インターコネクトロジック : GTH/GTYトランシーバとPL側ロジックの間に存在するインターフェイス的なロジック(実際はPL部分でロジック組まれてる？)かなり抽象的でブラックボックス化されていて、トランシーバの設定によって中身は変わるインターフェイス的な部分でPCSに含まれる。AXI interconnect IPみたいにバス幅を変換したりする役割。各チャンネル毎にインターコネクトを持つが、１つのチャネルのRXOUTCLKを各チャンネルのインターコネクトロジックに接続して、同期することが推奨されてる。8b10b設定の場合、インターコネクトはRX interfaceという部分に相当し、PCS内部バスが32bitでRXDATAポート幅が64bitだった場合に変換してる。

### 参考文献
* [Ultrascale FPGAs Transceivers Wizard](https://docs.xilinx.com/v/u/ja-JP/pg182-gtwizard-ultrascale)
* [7 Series FPGAs GTX/GTH Transceivers](http://padley.rice.edu/cms/OH_GE21/UG476_7Series_Transceivers.pdf)
* [Ultrascale Architechture GTH transceivers](https://docs.xilinx.com/v/u/ja-JP/ug576-ultrascale-gth-transceivers)
* [UltraScale Architechture GTY transceivers](https://docs.xilinx.com/v/u/ja-JP/ug578-ultrascale-gty-transceivers)
