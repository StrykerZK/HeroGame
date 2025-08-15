shader_type spatial;

uniform float dash_length = 0.5;
uniform float gap_length = 0.5;

void fragment() {
  float total_length = dash_length + gap_length;
  if (fract(UV.x / total_length) > dash_length / total_length) {
    discard;
  }
}