# Ohjeet

## Virtuaaliympäristön luominen

	python3 -m venv venv
	source venv/bin/activate
	pip install -r requirements.txt

## Sentencepiece-malli

`iso-lc` on sentencepiece-ohjelmalla luotu Unigram-malli, joka on koulutettu samalla aineistolla kuin alla oleva lstm2-malli.
Kaikki tämän repon ohjelmat käyttävät tätä mallia.

## Valmiiksi koulutettu malli

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

Tiedostoissa `Kalevala.ipynb` ja `Pyhis.ipynb` on esimerkit mallin hienosäätämisestä tietyntyyppisen tekstin generoimiseksi.

Data on tätä varten muutettava CSV-muotoon esimerkiksi seuraavasti:

	cat data.txt | sed -E '/^$/d;s/"/""/g;s/^|$/"/g' >data.csv
