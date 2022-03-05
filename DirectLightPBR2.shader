Shader "MyShader/PBR/DirectLightPBR2"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Roughness("Roughness",Range(0.02,1))=0.5
        _Metallic("Metallic",Range(0,1))=0.5
    	[KeywordEnum(Lambert, Disney)]_Diffuse("Diffuse Mode", Float) = 0
    }
     CGINCLUDE
        #include "UnityCG.cginc"
		#include "AutoLight.cginc"
        //D函数,采用GGX
        fixed D_GGX(fixed n_dot_h,fixed roughness)
        {
            fixed a=roughness*roughness;
            fixed denom= pow(n_dot_h,2)*(a*a-1)+1;
            return a*a*UNITY_INV_PI/(denom*denom+1e-5f);
        }
        //F函数，采用Schlick的Fresnel近似
        fixed3 F_Schlick(fixed3 F0,fixed v_dot_h)
        {
            return F0+(1-F0)*pow(1-v_dot_h,5);
        }
        //G函数，采用Schlick-GGX
        fixed G_Part_Schlick_GGX(fixed n_dot_v,fixed k)
        {
            return n_dot_v/((1-k)*n_dot_v+k);
        }
        fixed G_Schlick_GGX(fixed n_dot_l,fixed n_dot_v,fixed roughness)
        {
            fixed k=pow(roughness+1,2)/8;
            return G_Part_Schlick_GGX(n_dot_v,k)*G_Part_Schlick_GGX(n_dot_l,k);
        }
		float DisneyDiffuse(float roughness, float v_dot_h, float n_dot_l, float n_dot_v)
		{
			float fd90 = 0.5 + 2 * roughness * v_dot_h * v_dot_h;
     		float NdotLSqr = n_dot_l * n_dot_l;
     		float NdotVSqr = n_dot_v * n_dot_v;
     		float fd = 1.0 *UNITY_INV_PI * (1 + (fd90 - 1) * NdotLSqr * NdotLSqr * n_dot_l) * (1 + (fd90 - 1) * NdotVSqr * NdotVSqr * n_dot_v);
     		return fd;
		}
    ENDCG
    SubShader
    {   
        
        Tags { "RenderType"="Opaque"}
       
        Pass
        {
            Tags {"LightMode"="ForwardBase"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "Lighting.cginc"
            fixed4 _Color;
            fixed _Roughness;
            fixed _Metaness;
            struct a2v
            {
            	float4 vertex : POSITION;
				float3 normal : NORMAL;
            };
            struct v2f
            {
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				fixed3 worldNormal : TEXCOORD1;
				fixed3 worldViewDir : TEXCOORD2;
            };
            v2f vert(a2v v)
            {
                v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
				return o;
            }

            fixed4 frag(v2f i):SV_Target
            {
            	//-----------直射光部分---------------
            	//世界坐标下所有需要的向量
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));		
				fixed3 worldViewDir = normalize(i.worldViewDir);
				fixed3 h=normalize(worldLightDir+worldViewDir);

            	//通过一个预设值简化运算
            	fixed3 F0=lerp(0.04,_Color,_Metaness);

            	//提前运算所有需要的点乘值
            	fixed n_dot_h=saturate(dot(worldNormal,h));
            	fixed v_dot_h=saturate(dot(worldViewDir,h));
            	fixed n_dot_v=saturate(dot(worldNormal,worldViewDir));
            	fixed n_dot_l=saturate(dot(worldNormal,worldLightDir));

            	//每个函数值
				fixed D=D_GGX(n_dot_h,_Roughness);
            	fixed3 F=F_Schlick(F0,v_dot_h);
            	fixed G=G_Schlick_GGX(n_dot_l,n_dot_v,_Roughness);

            	//根据F和金属值计算kd
            	fixed3 oneMinusMetallic=(1-_Metallic);
                fixed3 diffuse=_Color*oneMinusMetallic;
            	
            	//漫反射
            	//原漫反射
            	#ifdef _DIFFUSE_LAMBERT
				diffuse *= UNITY_INV_PI*(1-F);
            	#endif
            	//Disney漫反射
				#ifdef _DIFFUSE_Disney
            	diffuse *= DisneyDiffuse(_Roughness, v_dot_h, n_dot_h, n_dot_v);
            	#endif
            	
            	//镜面反射
            	//分母加上1e-5f避免除0
            	fixed3 specular=F*D*G/(4*n_dot_l*n_dot_v+1e-5f);

            	//最终直射光得到结果
            	fixed3 directLight=(diffuse+specular)*_LightColor0.rgb*n_dot_l;
            	
            	return fixed4(directLight,1.0);
            }
            
            ENDCG
        }

    }
}
