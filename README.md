# Ohjeet

## Virtuaaliympäristön luominen

	python3 -m venv venv
	source venv/bin/activate
	pip install -r requirements.txt

## Sentencepiece-malli

`iso-lc` on sentencepiece-ohjelmalla luotu Unigram-malli, joka on koulutettu samalla aineistolla kuin alla oleva lstm2-malli.
Mallissa on 24000 sanaketta.
Kaikki tämän repon ohjelmat käyttävät tätä mallia.

## LSTM-malli

Projektissa käytetään [AWD-LSTM-mallia][awd-lstm], joka on toteutettu Fastai-kirjastossa.
Varsinaisessa mallissa on oletusasetusten mukaisesti 3 kerrosta, joissa on 1150, 1150 ja 400 LSTM-solua.

[awd-lstm]: https://arxiv.org/pdf/1708.02182.pdf

### Valmiiksi koulutettu malli

* [lstm2.pth][lstm2] – Koulutettu suomenkielisellä Wikipedialla (696 Mt), suomalaisilla eroottisilla novelleilla (103 Mt) ja Gutenberg-projektin suomenkielisillä teoksilla (464 Mt).

[lstm2]: http://iikkahau.users.cs.helsinki.fi/mallit/lstm2.pth

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
* `sekalaisia/filter-by-names.p6`: Skripi syö CONLL-U-tiedoston ja valitsee joukon erisnimiä ja filteröi pois lauseet, joissa ei käytetä näitä erisnimiä.
* `sekalaisia/find-nearest.p6`: Skriptillä voi etsiä tekstitiedostosta annetuilla sanoilla. Hyödyllinen, jos haluaa selvittää, mihin teksteihin generoitu teksti perustuu. Hitaahko.
* `sekalaisia/format-election-data.p6`: Skriptin avulla voi tehdä Markdown-tiedoston generoidusta vaalikonedatasta.
