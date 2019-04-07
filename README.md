# Ohjeet

## Virtuaaliympäristön luominen

	python3 -m venv venv
	source venv/bin/activate
	pip install -r requirements.txt

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
