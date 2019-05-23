# Ohjeet

## Virtuaaliympäristön luominen

	python3 -m venv venv
	source venv/bin/activate
	pip install -r requirements.txt

## Sentencepiece-malli

`iso-lc` on sentencepiece-ohjelmalla luotu Unigram-malli, joka on koulutettu samalla aineistolla kuin alla oleva lstm2-malli.
Mallissa on 24000 sanaketta.
Kaikki tämän repon ohjelmat käyttävät tätä mallia.

## Kielimallit

Mallit on koulutettu suomenkielisellä Wikipedialla (696 Mt), suomalaisilla eroottisilla novelleilla (103 Mt) ja Gutenberg-projektin suomenkielisillä teoksilla (464 Mt).
Mallien kouluttamiseen on käytetty [Fastai-kirjastoa][fastai] ja sen oletusasetuksia.

* [lstm2.pth][lstm2] – Valmiiksi koulutettu [AWD-LSTM-malli][awd-lstm].
* [tf1.pth][tf1] – Valmiiksi koulutettu [Transformer-malli][transformer].
* [txl1.pth][txl1] – Valmiiksi koulutettu [TransformerXL-malli][transformerxl].

[fastai]: https://docs.fast.ai/text.models.html
[lstm2]: http://iikkahau.users.cs.helsinki.fi/mallit/lstm2.pth
[tf1]: http://iikkahau.users.cs.helsinki.fi/mallit/tf1.pth
[txl1]: http://iikkahau.users.cs.helsinki.fi/mallit/txl1.pth
[awd-lstm]: https://arxiv.org/pdf/1708.02182.pdf
[transformer]: https://arxiv.org/pdf/1706.03762.pdf
[transformerxl]: https://arxiv.org/pdf/1901.02860.pdf

## Mallin kouluttaminen ja käyttäminen

Oletetaan, että aineisto on tiedostossa `aineisto.txt`.
Aineisto voidaan enkoodata seuraavasti:

	python3 encode.py aineisto.txt aineisto.npy

Tämän jälkeen kielimalli voidaan kouluttaa seuraavasti:

	python3 train-model.py iso-lc.vocab aineisto.npy 5

Komento tallentaa luomansa mallit `models/`-kansioon.
Luodun mallin avulla voi arpoa tekstiä interaktiivisesti seuraavasti:

	python3 sample-model.py iso-lc final_model

Interaktiivisessa tilassa voi antaa kehotteen, ja mallin avulla arvotaan tekstiä joka todennäköisesti tulisi kehotteen perään.
On myös mahdollista muuttaa joitain parametreja komennoilla, erityisesti `/n <pituus>` muuttaa generoitavan tekstin pituutta
ja `/temp <luku>` muuttaa todennäköisyysjakauman skaalauslukua (0.7 on yleensä hyvä).

## Mallin hienosäätäminen

Tiedostoissa `Kalevala.ipynb`, `Vaalidata.ipynb` ja `Pyhis.ipynb` on esimerkit mallin hienosäätämisestä tietyntyyppisen tekstin generoimiseksi.

Data on tätä varten muutettava CSV-muotoon esimerkiksi seuraavasti:

	cat data.txt | sed -E '/^$/d;s/"/""/g;s/^|$/"/g' >data.csv

## Sekalaisia skriptejä

* `data/vaalidata.p6`: Muuttaa Ylen vaalidatan alkuperäisestä CSV-muodosta yksisarakkeiseen CSV-muotoon, jonka voi syöttää helposti mallille.
* `sekalaista/filter-by-names.p6`: Skripi syö CONLL-U-tiedoston ja valitsee joukon erisnimiä ja filteröi pois lauseet, joissa ei käytetä näitä erisnimiä.
* `sekalaista/find-nearest.p6`: Skriptillä voi etsiä tekstitiedostosta annetuilla sanoilla. Hyödyllinen, jos haluaa selvittää, mihin teksteihin generoitu teksti perustuu. Hitaahko.
* `sekalaista/format-election-data.p6`: Skriptin avulla voi tehdä Markdown-tiedoston generoidusta vaalikonedatasta.
