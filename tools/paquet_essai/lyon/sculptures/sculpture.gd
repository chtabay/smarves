extends RefCounted
## Les sculptures modelées à part (sculpter.py) : leur maillage, lu dans <nom>.bin, et leur bronze patiné.
## Partagé par lyon.gd et par l'aperçu (apercu.gd).


## Le maillage d'une sculpture : positions, normales, occlusion (dans la couleur des sommets), indices.
static func maillage(chemin: String) -> ArrayMesh:
	var f := FileAccess.open(chemin, FileAccess.READ)
	var nv := f.get_32()
	var ni := f.get_32()
	var pos := f.get_buffer(nv * 12).to_float32_array()
	var nor := f.get_buffer(nv * 12).to_float32_array()
	var occ := f.get_buffer(nv * 4).to_float32_array()
	var idx := f.get_buffer(ni * 4).to_int32_array()
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	v.resize(nv)
	n.resize(nv)
	c.resize(nv)
	for k in nv:
		v[k] = Vector3(pos[k * 3], pos[k * 3 + 1], pos[k * 3 + 2])
		n[k] = Vector3(nor[k * 3], nor[k * 3 + 1], nor[k * 3 + 2])
		c[k] = Color(occ[k], occ[k], occ[k])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## Le bronze patiné : brun sombre dans les creux, vert-de-gris clair sur les saillies tournées vers le ciel.
static func bronze(sombre: Color, patine: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 sombre : source_color;
uniform vec3 patine : source_color;
varying float ciel;
void vertex() { ciel = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y; }
void fragment() {
	float creux = COLOR.r;
	vec3 c = mix(sombre * 0.55, sombre, creux);
	c = mix(c, patine, smoothstep(0.2, 0.9, ciel) * creux * 0.8);
	ALBEDO = c;
	METALLIC = 0.25;
	ROUGHNESS = mix(0.7, 0.4, creux);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("sombre", sombre)
	m.set_shader_parameter("patine", patine)
	return m
