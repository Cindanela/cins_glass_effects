#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Baked-SDF variant of glass.frag: identical optics, but the signed distance
// `d` is read from a texture (sampler 1) instead of an analytic rounded-box.
// This is what gives *any* silhouette — polygons, blobs, bars with holes —
// full shader fidelity. Keep the optics core in lockstep with glass.frag.

layout(location = 0) uniform vec2  uSize;         // floats 0,1 (engine: input size)
layout(location = 1) uniform vec2  uLightDir;     // 2,3
layout(location = 2) uniform float uRefraction;   // 4
layout(location = 3) uniform float uChromatic;    // 5
layout(location = 4) uniform float uSpecular;     // 6
layout(location = 5) uniform float uShininess;    // 7
layout(location = 6) uniform float uFresnel;      // 8
layout(location = 7) uniform vec4  uTint;         // 9,10,11,12
layout(location = 8) uniform float uEdgeWidth;    // 13
layout(location = 9) uniform float uIntensity;    // 14 (light intensity)
layout(location = 10) uniform float uSdfRange;    // 15 (px spanned by [-1,1] decode)
layout(location = 11) uniform float uGrain;       // 16 (frost grain strength)
// The backdrop input texture is the WHOLE render pass (screen), not the widget
// bounds — the widget's rect within it must be passed in (device px).
layout(location = 12) uniform vec2 uRectOrigin;   // 17,18
layout(location = 13) uniform vec2 uRectSize;     // 19,20

uniform sampler2D uTexture;                        // sampler 0: backdrop (engine-bound)
uniform sampler2D uSdfTexture;                     // sampler 1: baked signed-distance field

out vec4 fragColor;

// Decode the field at a normalised position: 0.5 is the edge, <0.5 inside.
// Result is in the same pixel units as fragCoord (uSdfRange carries the
// spread × device-pixel-ratio scaling done on the Dart side).
float sdfAt(vec2 uvField) {
  float raw = texture(uSdfTexture, uvField).r;
  return (raw - 0.5) * uSdfRange;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  // Field uv: position within the widget rect (our own texture: never flipped).
  vec2 uvField = (fragCoord - uRectOrigin) / uRectSize;
  vec2 uv = fragCoord / uSize;        // backdrop: input-texture space
// Impeller's GL backend samples the backdrop upside-down; flip at compile time.
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  float d = sdfAt(uvField);                          // negative inside

  // Surface normal from the field gradient (finite differences, one device
  // pixel expressed in field-uv units).
  vec2 e = vec2(1.0) / uRectSize;
  float gx = sdfAt(uvField + vec2(e.x, 0.0)) - sdfAt(uvField - vec2(e.x, 0.0));
  float gy = sdfAt(uvField + vec2(0.0, e.y)) - sdfAt(uvField - vec2(0.0, e.y));
  vec2 grad = normalize(vec2(gx, gy) + vec2(1e-5));

  // Edge band: 1 at the rim, 0 deep inside.
  float depth = -d;                                  // px inside (positive)
  float edge = 1.0 - smoothstep(0.0, uEdgeWidth, depth);
  edge = clamp(edge, 0.0, 1.0);

  // Refraction + chromatic aberration: sample the backdrop, displaced along
  // the inward normal, more strongly near the edges.
  vec2 refr = grad * (uRefraction * edge) / uSize;
  vec2 ca   = grad * (uChromatic  * edge) / uSize;
  float rC = texture(uTexture, uv + refr + ca).r;
  float gC = texture(uTexture, uv + refr).g;
  float bC = texture(uTexture, uv + refr - ca).b;
  vec3 color = vec3(rC, gC, bC);

  // Glass tint.
  color = mix(color, uTint.rgb, uTint.a);

  // Fresnel rim brightening, scaled by how strong the light is.
  color += vec3(pow(edge, 2.0) * uFresnel * uIntensity);

  // Specular highlight off the beveled edge.
  vec3 n = normalize(vec3(grad * edge, 1.0));
  vec3 l = normalize(vec3(uLightDir, 1.0));
  float spec = pow(max(dot(n, l), 0.0), max(uShininess, 1.0)) * uSpecular * uIntensity;
  color += vec3(spec);

  // Frosted grain: hash noise in widget-local coords (stable as the widget
  // moves), strongest where the tint/frost reads as surface.
  vec2 local = uvField * uRectSize;
  float noise = fract(sin(dot(local, vec2(12.9898, 78.233))) * 43758.5453);
  color += (noise - 0.5) * uGrain * 0.25;

  // No mask here: the widget's ClipPath cuts the exact anti-aliased
  // silhouette. The baked field is too coarse for a 2 px mask band (staircase
  // edges); it only needs to drive the optics, which fade over uEdgeWidth.
  fragColor = vec4(color, 1.0);
}
