#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
layout(location = 0) uniform vec2 uSize;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  fragColor = texture(uTexture, uv);
}
