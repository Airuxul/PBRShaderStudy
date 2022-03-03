Shader "MyShader/PBR/DirectLightPBR1"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Roughness("Roughness",Range(0.02,1))=0.5
        _Metaness("Metaness",Range(0,1))=0.5
    	
    }
     CGINCLUDE
        #include "UnityCG.cginc"
		#include "AutoLight.cginc"
        //D函数,采用GGX
        fixed D_GGX(fixed3 n,fixed3 h,fixed roughness)
        {
            fixed a=roughness*roughness;
            fixed denom= pow(saturate(dot(n,h)),2)*(a*a-1)+1;
            return a*a*UNITY_INV_PI/(denom*denom+1e-5f);
        }
     
        //F函数，采用Schlick的Fresnel近似
        fixed3 F_Schlick(fixed3 F0,fixed3 v,fixed3 h)
        {
            return F0+(1-F0)*pow(1-saturate(dot(v,h)),5);
        }
        //G函数，采用Schlick-GGX
        fixed G_Part_Schlick_GGX(fixed3 n,fixed3 v,fixed k)
        {
            return saturate(dot(n,v))/((1-k)*saturate(dot(n,v))+k);
        }
        fixed G_Schlick_GGX(fixed3 n,fixed3 l,fixed3 v,fixed roughness)
        {
            fixed k=pow(roughness+1,2)/8;
            return G_Part_Schlick_GGX(n,v,k)*G_Part_Schlick_GGX(n,l,k);
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
				//通过一个预设值简化计算F0的过程
            	fixed3 F0=lerp(0.04,_Color,_Metaness);
				//每个函数值
				fixed D=D_GGX(worldNormal,h,_Roughness);
            	fixed3 F=F_Schlick(F0,worldViewDir,h);
            	fixed G=G_Schlick_GGX(worldNormal,worldLightDir,worldViewDir,_Roughness);
				//根据F和金属值计算kd
				fixed3 kd=(1-F)*(1-_Metaness);
            	//漫反射
            	fixed3 diffuse=_Color*kd/UNITY_PI;
            	//镜面反射
				//分母加上1e-5f避免除0
            	fixed3 specular=F*D*G/(4*saturate(dot(worldNormal,worldLightDir))*saturate(dot(worldNormal,worldViewDir))+1e-5f);
            	//最终直射光得到结果
            	fixed3 directLight=(diffuse+specular)*_LightColor0.rgb*saturate(dot(worldNormal,worldLightDir));
            	return fixed4(directLight,1.0);
            }
            
            ENDCG
        }

    }
}
