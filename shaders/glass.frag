#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

layout(location = 0) uniform vec2  uSize;         // floats 0,1 (engine: input size)
layout(location = 1) uniform vec2  uLightDir;     // 2,3
layout(location = 2) uniform float uRefraction;   // 4
layout(location = 3) uniform float uChromatic;    // 5
layout(location = 4) uniform float uSpecular;     // 6
layout(location = 5) uniform float uShininess;    // 7
layout(location = 6) uniform float uFresnel;      // 8
layout(location = 7) uniform vec4  uTint;         // 9,10,11,12
layout(location = 8) uniform float uCornerRadius; // 13
layout(location = 9) uniform float uEdgeWidth;    // 14
layout(location = 10) uniform float uYFlip;       // 15

uniform sampler2D uTexture;                        // sampler 0: backdrop

out vec4 fragColor;

// MUST stay identical to ShapeSdf.roundedRect (Dart twin).
float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  if (uYFlip > 0.5) { uv.y = 1.0 - uv.y; }

  vec2 halfSize = uSize * 0.5;
  vec2 p = fragCoord - halfSize;
  vec2 b = halfSize - vec2(1.0);

  float d = sdRoundedBox(p, b, uCornerRadius);      // negative inside

  // Surface normal from the SDF gradient (finite differences).
  const float e = 1.0;
  float gx = sdRoundedBox(p + vec2(e, 0.0), b, uCornerRadius) -
             sdRoundedBox(p - vec2(e, 0.0), b, uCornerRadius);
  float gy = sdRoundedBox(p + vec2(0.0, e), b, uCornerRadius) -
             sdRoundedBox(p - vec2(0.0, e), b, uCornerRadius);
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

  // Fresnel rim brightening.
  color += vec3(pow(edge, 2.0) * uFresnel);

  // Specular highlight off the beveled edge.
  vec3 n = normalize(vec3(grad * edge, 1.0));
  vec3 l = normalize(vec3(uLightDir, 1.0));
  float spec = pow(max(dot(n, l), 0.0), max(uShininess, 1.0)) * uSpecular;
  color += vec3(spec);

  // Anti-aliased mask to the rounded-rect shape.
  float mask = 1.0 - smoothstep(-1.0, 1.0, d);
  fragColor = vec4(color, 1.0) * mask;
}
