#iChannel0 'file://./bufferB.glsl'

// inspired from http://evasion.imag.fr/~Fabrice.Neyret/demos/JS/Vort.html


void mainImage( out vec4 O,  vec2 U )
{
	O = texture(iChannel0,U/iResolution.xy);   
}