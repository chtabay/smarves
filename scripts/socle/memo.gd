class_name Memo
extends RefCounted
## Ce qu'un lieu calcule à sa construction et qui ne dépend que du code : une figurine, une image peinte
## pixel par pixel. Calculé une fois, gardé sur l'appareil (user://cache), relu aux lancements suivants.
##
## Chaque famille a son dossier, par version du script qui fabrique la valeur (son empreinte MD5) : un
## changement du script jette tout ce qu'il avait calculé, et les versions précédentes sont supprimées
## au premier passage. Une clé identifie la valeur dans sa famille (entier, texte ou dictionnaire).

const DOSSIER := "user://cache/"

static var _versions := {}
static var _memoire := {}


## La valeur de `cle` dans `famille`, fabriquée par `fabrique` (sans argument) si elle n'est ni en mémoire ni
## sur l'appareil. Elle doit se ranger avec store_var sans objet : tableaux compacts, nombres, textes, dictionnaires.
## Relue du fichier à chaque appel : c'est à l'appelant de garder ce qu'il en fait (son maillage, par exemple).
static func valeur(famille: String, script: String, cle, fabrique: Callable) -> Variant:
	var chemin := _dossier(famille, script) + "%d.bin" % _cle(famille, cle)
	var v = _relire(chemin)
	if v == null:
		v = fabrique.call()
		_ranger(chemin, v)
	return v


## Une texture dont l'image se peint dans le code : `fabrique` rend une Image, on garde ses pixels, et la
## texture reste en mémoire le temps du lancement.
static func image(famille: String, script: String, cle, fabrique: Callable) -> ImageTexture:
	var k := _cle(famille, cle)
	if _memoire.has(k):
		return _memoire[k]
	var chemin := _dossier(famille, script) + "%d.bin" % k
	var img: Image = null
	var d = _relire(chemin)
	if d is Dictionary and d.has_all(["w", "h", "m", "f", "data"]):
		img = Image.create_from_data(d.w, d.h, d.m, d.f, d.data)
	if img == null:
		img = fabrique.call()
		_ranger(chemin, {"w": img.get_width(), "h": img.get_height(), "m": img.has_mipmaps(), "f": img.get_format(), "data": img.get_data()})
	var tex := ImageTexture.create_from_image(img)
	_memoire[k] = tex
	return tex


## Une texture de bruit (NoiseTexture2D) : le moteur la calcule à la première image, sur le fil principal,
## 80 ms pour 512 × 512 (la place en a douze : une seconde avant sa première image). Au premier passage
## elle sert telle quelle et ses pixels sont rangés dès qu'ils sont prêts ; ensuite c'est l'image rangée.
static func bruit(famille: String, script: String, cle, texture: NoiseTexture2D) -> Texture2D:
	var k := _cle(famille, cle)
	if _memoire.has(k):
		return _memoire[k]
	var chemin := _dossier(famille, script) + "%d.bin" % k
	var d = _relire(chemin)
	if d is Dictionary and d.has_all(["w", "h", "m", "f", "data"]):
		var tex := ImageTexture.create_from_image(Image.create_from_data(d.w, d.h, d.m, d.f, d.data))
		_memoire[k] = tex
		return tex
	texture.changed.connect(func():
		var img := texture.get_image()
		if img:
			_ranger(chemin, {"w": img.get_width(), "h": img.get_height(), "m": img.has_mipmaps(), "f": img.get_format(), "data": img.get_data()})
		, CONNECT_ONE_SHOT)
	_memoire[k] = texture
	return texture


## Vide les textures gardées en mémoire (les fichiers restent) ; pour les tests.
static func oublier() -> void:
	_memoire.clear()


static func _cle(famille: String, cle) -> int:
	return hash(famille + "|" + var_to_str(cle))


static func _dossier(famille: String, script: String) -> String:
	if not _versions.has(famille):
		var version := FileAccess.get_md5(script).left(12)
		var base := DOSSIER + famille + "/"
		var da := DirAccess.open("user://")
		if da:
			da.make_dir_recursive(base + version)
			for d in DirAccess.get_directories_at(base):
				if d != version:
					for f in DirAccess.get_files_at(base + d):
						da.remove(base + d + "/" + f)
					da.remove(base + d)
		_versions[famille] = base + version + "/"
	return _versions[famille]


static func _ranger(chemin: String, v) -> void:
	var f := FileAccess.open_compressed(chemin, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f:
		f.store_var(v)


static func _relire(chemin: String) -> Variant:
	if not FileAccess.file_exists(chemin):
		return null
	var f := FileAccess.open_compressed(chemin, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return null
	return f.get_var()
