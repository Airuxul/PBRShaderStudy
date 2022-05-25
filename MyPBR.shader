Shader "MyShader/PBR/MyPBR"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Roughness("Roughness",Range(0,1))=0.5
        _Metallic("Metallic",Range(0,1))=0.5
    	[KeywordEnum(Lambert, Disney)]_Diffuse("Diffuse Mode", Float) = 0
    }
     CGINCLUDE
        #include "UnityCG.cginc"
		#include "AutoLight.cginc"
		#include "UnityLightingCommon.cginc" 
		#include "UnityStandardConfig.cginc"
        //D����,����GGX
        fixed D_GGX(fixed n_dot_h,fixed roughness)
        {
            fixed a=roughness*roughness;
            fixed denom= pow(n_dot_h,2)*(a*a-1.0)+1.0;
            return a*a*UNITY_INV_PI/(denom*denom+1e-5f);
        }
        //F����������Schlick��Fresnel����
        fixed3 F_Schlick(fixed3 F0,fixed v_dot_h)
        {
            return F0+(1-F0)*pow(1-v_dot_h,5);
        }
        //G����������Schlick-GGX
        fixed G_Part_Schlick_GGX(fixed n_dot_v,fixed k)
        {
            return n_dot_v/((1-k)*n_dot_v+k);
        }
        fixed G_Schlick_GGX(fixed n_dot_l,fixed n_dot_v,fixed roughness)
        {
            fixed k=pow(roughness+1,2)/8;
            return G_Part_Schlick_GGX(n_dot_v,k)*G_Part_Schlick_GGX(n_dot_l,k);
        }
		//��ʿ��������
		fixed DisneyDiffuse(float roughness, float v_dot_h, float n_dot_l, float n_dot_v)
		{
			float fd90 = 0.5 + 2 * roughness * v_dot_h * v_dot_h;
     		float fd = UNITY_INV_PI * (1 + (fd90 - 1) *pow(1-n_dot_l,5)) * (1 + (fd90 - 1) * pow(1-n_dot_v,5));
     		return fd;
		}
		//�����˴ֲڶ����ӵ�F�����������Ʒ�����˥������
        fixed3 F_Schlick_Roughness(fixed3 n_dot_v,float3 F0,fixed roughness)
		{
     		return F0 + (max(1.0-roughness, F0) - F0) * pow(1.0 - n_dot_v, 5.0);
		}
		//��ֵ��Ϻ���
		float2 EnvBRDFApprox(float Roughness, float NoV )
		{
     		const float4 c0 = { -1, -0.0275, -0.572, 0.022 };
     		const float4 c1 = { 1, 0.0425, 1.04, -0.04 };
     		float4 r = Roughness * c0 + c1;
     		float a004 = min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
     		float2 AB = float2( -1.04, 1.04 ) * a004 + r.zw;
     		return AB;
		}
		//ɫ��ӳ��
		 float3 ACESToneMapping(float3 x)
		{
     		float a = 2.51f;
     		float b = 0.03f;
     		float c = 2.43f;
     		float d = 0.59f;
     		float e = 0.14f;
     		return saturate((x*(a*x+b))/(x*(c*x+d)+e));
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
            fixed _Metallic;
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
            	//-----------ֱ��ⲿ��---------------
            	//����������������Ҫ������
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));		
				fixed3 worldViewDir = normalize(i.worldViewDir);
				fixed3 h=normalize(worldLightDir+worldViewDir);

            	//ͨ��һ��Ԥ��ֵ������
            	fixed3 F0=lerp(0.04,_Color,_Metallic);

            	//��ǰ����������Ҫ�ĵ��ֵ
            	fixed n_dot_h=saturate(dot(worldNormal,h));
            	fixed v_dot_h=saturate(dot(worldViewDir,h));
            	fixed n_dot_v=saturate(dot(worldNormal,worldViewDir));
            	fixed n_dot_l=saturate(dot(worldNormal,worldLightDir));

            	//ÿ������ֵ
				fixed D=D_GGX(n_dot_h,_Roughness);
            	fixed3 F=F_Schlick(F0,v_dot_h);
            	fixed G=G_Schlick_GGX(n_dot_l,n_dot_v,_Roughness);

            	//����F�ͽ���ֵ����kd
            	fixed3 oneMinusMetallic=(1-_Metallic);
                fixed3 diffuse=_Color*oneMinusMetallic;
            	
            	//������
            	//ԭ������
             	#ifdef _DIFFUSE_LAMBERT
				 diffuse *= UNITY_INV_PI*(1-F);
             	#endif
             	//Disney������
				 #ifdef _DIFFUSE_Disney
            	//ʹ�õ�ʿ�����������������⣿�����,��ʽ�����⣬ܳ
             	diffuse *= DisneyDiffuse(_Roughness, v_dot_h, n_dot_h, n_dot_v);
             	#endif
            	
            	//���淴��
            	//��ĸ����1e-5f�����0
            	fixed3 specular=F*D*G/(4*n_dot_l*n_dot_v+0.00001);

            	//����ֱ���õ����
            	fixed3 directLight=(diffuse+specular)*_LightColor0.rgb*n_dot_l;
            	
            	//-----------��ӹⲿ��---------------
            	//�����䲿��
            	fixed3 worldReflect=reflect(-worldViewDir,worldNormal);
				float3 irradianceSH = ShadeSH9(float4(worldNormal,1));

            	//���淴�䲿��
            	//��һ����
            	//���ݴֲڶȻ�ȡmip
            	fixed mip = _Roughness * (1.7 - 0.7 * _Roughness) * UNITY_SPECCUBE_LOD_STEPS;
            	//����Ԥ���˻�����ͼ��ע�ⳡ����Ҫ����ReflectionProbe���決���ܻ�ȡunity_SpecCube0_HDR
                float4 rgb_mip = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0,worldReflect,mip);
            	//����HDR��ʽ��RGB
                fixed3 envSpecularPrefilted = DecodeHDR(rgb_mip, unity_SpecCube0_HDR);

            	//�ڶ�����
            	//����F0
            	fixed3 F_IndirectLight=F_Schlick_Roughness(n_dot_v,F0,_Roughness);
            	//����1��ͨ��BRDFLut��ȡ
            	//float2 env_brdf=float2 env_brdf = tex2D(_BRDFLUTTex, float2(n_dot_v,_Roughness)).rg;
            	//����2����ֵ����
                float2 env_brdf = EnvBRDFApprox(_Roughness,n_dot_v);

            	//���淴�����ս��
                float3 specular_Indirect = envSpecularPrefilted  * (F_IndirectLight * env_brdf.r + env_brdf.g);

            	//����F0�����ӹ��kd       
                float3 kd_Indirect = float3(1,1,1) - F_IndirectLight;
            	kd_Indirect *= (1 - _Metallic);

            	//�õ���ӹ�������
                float3 diffuse_Indirect = irradianceSH * _Color *kd_Indirect;
            	//�õ����ռ�ӹ���
                float3 indirectLight = diffuse_Indirect + specular_Indirect;
            	
            	//�õ����ս��
                float4 finalColor =0;
                finalColor.rgb = directLight + indirectLight;
            	//ͨ��ɫ��ӳ����к�����Unity�ڲ�shader�Ĵ���һ������������Ч���ӽ�
                finalColor.rgb = ACESToneMapping(finalColor.rgb);
            	return fixed4(finalColor.rgb,1.0);
            }
            ENDCG
        }

    }
}
