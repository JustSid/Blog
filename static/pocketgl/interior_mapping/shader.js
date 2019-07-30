  var asset_path = "/pocketgl/interior_mapping/";
  
  new PocketGL("container", { autoOrbit: true, cameraYaw: 180 + 90,cameraPitch: 12, cameraDistance: 45, editorTheme : "bright",
                             vertexShaderFile: "vertex.glsl",
                             fragmentShaderFile: "fragment.glsl",
                             skybox: [
"cubemap/px.jpg", "cubemap/nx.jpg", 
"cubemap/py.jpg", "cubemap/ny.jpg", 
"cubemap/pz.jpg", "cubemap/nz.jpg",
], meshes: [
{ type: "plane", name: "Plane", doubleSided: true },
{ type: "cube", name: "Cube"},
{ type: "teapot", name: "Teapot" },
{ type: "sphere", name: "Sphere"},
{ type: "torus", name: "Torus"},
{ type: "cylinder", name: "Cylinder"},
], textures: [
{ 
  url: "diffuse.png", 
  name: "diffuseTexture"
},
{ 
  url: "floor_ceiling.png", 
  name: "floorCeilingTexture"
},
{ 
  url: "wallAtlas.png", 
  name: "wallAtlasTexture"
},
{ 
  url: "bricks.png", 
  name: "brickTexture"
}
], uniforms: [
  { type: "float", value: 7.98, min: 1, max: 15, name: "ceilingFrequency", GUIName: "Ceiling frequency" },
  { type: "float", value: 4.06, min: 1, max: 15, name: "wallFrequencyX", GUIName: "Wall frequency X" },
  { type: "float", value: 4.06, min: 1, max: 15, name: "wallFrequencyZ", GUIName: "Wall frequency Z" },
  { type: "float", value: 0.04, min: 0, max: 1, name: "scale", GUIName: "Scale" },
  { type: "boolean", value: true, name: "showOutside", GUIName: "Show outside" },
  { type: "boolean", value: true, name: "showInterior", GUIName: "Show interior" }
], zoom: true }, asset_path);