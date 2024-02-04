Shader "Retro3D/RetroShadowCaster"
{
    Properties
    {
        _MainTex("Base", 2D) = "white" {}
        _EmptyTex("Leave Empty Unless Funkiness Wanted", 2D) = "white" {}
        _Color("Color", Color) = (0.5, 0.5, 0.5, 1)
        _GeoRes("Geometric Resolution", Float) = 40
    }
    SubShader
    {
        Pass
        {
            Tags {"LightMode"="ForwardBase"}
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            // compile shader into multiple variants, with and without shadows
            // (we don't care about any lightmaps yet, so skip these variants)
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            // shadow helper functions and macros
            #include "AutoLight.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 texcoord : TEXCOORD0; //worldPos, uv

                SHADOW_COORDS(1) // put shadows data into TEXCOORD1
                fixed3 diff : COLOR0;
                fixed3 ambient : COLOR1;
            };

            sampler2D _MainTex;
            sampler2D _EmptyTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _GeoRes;

            v2f vert(appdata_base v) //appdata_base: position, normal and one texture coordinate.
            {
                v2f o;

                //vertex warping
                float4 wp = mul(UNITY_MATRIX_MV, v.vertex);
                wp.xyz = floor(wp.xyz * _GeoRes) / _GeoRes;

                //placing shader in world (?) reletive to camera
                float4 sp = mul(UNITY_MATRIX_P, wp);
                o.pos = sp; //e.g adding 5 to this makes it out of sync

                //mapping texture (e.g mult by 0.5 makes the texture 2x larger)
                float2 uv = TRANSFORM_TEX(v.texcoord, _MainTex); //linked with _MainTex_ST???
                o.texcoord = float3(uv * sp.w, sp.w);
                //o.texcoord = float3(uv * sp.w, sp.w);

                //shadowy code
                //o.pos = UnityObjectToClipPos(v.vertex);
                //o.texcoord = v.texcoord;
                half3 worldNormal = UnityObjectToWorldNormal(v.normal);
                half nl = max(0.05, dot(worldNormal, _WorldSpaceLightPos0.xyz));
                o.diff = nl * _LightColor0.rgb;
                o.ambient = ShadeSH9(half4(worldNormal,1));
                // compute shadows data
                TRANSFER_SHADOW(o)

                return o;
            }

            
            fixed4 frag(v2f i) : SV_Target //colour of pixels
            {
                float2 uv = i.texcoord.xy / i.texcoord.z;

                fixed4 col = tex2D(_EmptyTex, i.texcoord);
                // compute shadow attenuation (1.0 = fully lit, 0.0 = fully shadowed)
                fixed shadow = SHADOW_ATTENUATION(i);
                // darken light's illumination with shadow, keep ambient intact
                fixed3 lighting = i.diff * shadow + i.ambient;
                col.rgb *= lighting;

                return tex2D(_MainTex, uv) * _Color * col * 5;
            }
            

            ENDCG
        }
        Pass //custom SHADOWCASTER pass 
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
         
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
 
            float _GeoRes;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            struct v2f {
                float3 texcoord : TEXCOORD0; //worldPos, uv
                V2F_SHADOW_CASTER;
            };
 
            v2f vert( appdata_base v )
            {
                v2f o;
                //TRANSFER_SHADOW_CASTER_NORMALOFFSET(o) // this has to be BEFORE the transformation!!!
                //so, this works lovely but each vertex transformation causes a shadow from it, which is
                //much horrendous and makes flat shadows the only real option
                /*
                //vertex warping
                float4 wp = mul(UNITY_MATRIX_MV, v.vertex);
                wp.xyz = floor(wp.xyz * _GeoRes) / _GeoRes;

                //placing shader in world (?) reletive to camera
                float4 sp = mul(UNITY_MATRIX_P, wp);
                o.pos = sp; //e.g adding 5 to this makes it out of sync

                //mapping texture (e.g mult by 0.5 makes the texture 2x larger)
                float2 uv = TRANSFORM_TEX(v.texcoord, _MainTex); //linked with _MainTex_ST???
                o.texcoord = float3(uv * sp.w, sp.w);
                */
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
					
                return o;
            }
 
            float4 frag( v2f i ) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
        // shadow casting support
        //UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
