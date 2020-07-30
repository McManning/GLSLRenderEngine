
Shader {
    Properties {
        // Propertites that you define here become editable
        // in the UI and available as uniforms under the same
        // name and type to every program.
        _Ambient("Ambient Color", color)
        _Normal("Normal", texture2D)

        _f("test float", float) = 0.5
        _i("test int", int) = 5
        _v2("test v2", vec2) = (0.1, 0.2)
        _v3("test v3", vec3) = (0.1, 0.2, 0.3)
        _v4("test v4", vec4) = (0.1, 0.2, 0.3, 0.4)

        // Color defines a custom UI control that translates
        // to a vec4 uniform during compilation.
        _color("test color", color) = (0.1, 0.2, 0.3, 0.4)

        // Textures can default to a builtin texture name.
        _tex("test texture", texture2D) = "white"

        // Automatic type detection
        _df("test float") = 0.5
        _di("test int") = 5
        _dv2("test v2") = (0.1, 0.2)
        _dv3("test v3") = (0.1, 0.2, 0.3)
        _dv4("test v4") = (0.1, 0.2, 0.3, 0.4)

        // Color would just render a vec4 control if not typehinted.
        _dcolor("test color") = (0.1, 0.2, 0.3, 0.4)

        // You *must* typehint textures, for now.
        // _dtex("test texture") = "white"
    }

    GLSL Common {
        vec3 lambert(vec3 lightColor, vec3 lightDir, vec3 normal) {
            float NdotL = clamp(dot(normal, lightDir), 0.0, 1.0);
            return lightColor * NdotL;
        }
    }

    GLSL MyVS {               
        out VS_OUT {
            vec3 positionWS;
            vec3 normalWS;
        } OUT;

        void main() {
            gl_Position = ModelViewProjectionMatrix * vec4(Position, 1.0);
            vec3 positionWS = (ModelMatrix * vec4(Position, 1.0)).xyz;
            vec3 normalWS = (ModelMatrix * vec4(Normal, 0)).xyz;
            
            OUT.positionWS = positionWS;
            OUT.normalWS = normalWS;
        }
    }

    GLSL MyGS {        
        layout (triangles) in;
        layout (triangle_strip, max_vertices = 3) out;
    
        in VS_OUT {
            vec3 positionWS;
            vec3 normalWS;
        } IN[];

        out GS_OUT {
            vec3 positionWS;
            vec3 normalWS;
        } OUT;
        
        void main() {
            gl_Position = gl_in[0].gl_Position;
            OUT.positionWS = IN[0].positionWS;
            OUT.normalWS = IN[0].normalWS;
            EmitVertex();

            gl_Position = gl_in[1].gl_Position;
            OUT.positionWS = IN[1].positionWS;
            OUT.normalWS = IN[1].normalWS;
            EmitVertex();

            gl_Position = gl_in[2].gl_Position;
            OUT.positionWS = IN[2].positionWS;
            OUT.normalWS = IN[2].normalWS;
            EmitVertex();

            EndPrimitive();
        }
    }

    GLSL MyFS {
        in GS_OUT {
            vec3 positionWS;
            vec3 normalWS;
        } IN;

        void main() {
            vec3 diffuse = lambert(_MainLightColor.rgb, _MainLightDirection.xyz, IN.normalWS);
            FragColor = vec4(diffuse + _AmbientColor.rgb, 1);
        } 
    }

    GLSL ShadowFS {
        void main() {
            FragColor = vec4(0, 0, 0, 1);
        }
    }

    GLSL ComputeTexture {
        // Would be executed per-pixel

        // would be defined in properties
        uniform float roll;

        // VBOs would be bound as readonly SSBOs

        // uses image2D instead of sampler2D.
        // Would be an autogenerated output for
        // this type of compute.
        uniform image2D destTex;

        layout(local_size_x = 16, local_size_y = 16) in;

        void main() {
            ivec2 storePos = ivec2(gl_GlobalInvocationID.xy);
            float localCoef = length(vec2(ivec2(gl_LocalInvocationID.xy)-8)/8.0);
            float globalCoef = sin(float(gl_WorkGroupID.x+gl_WorkGroupID.y)*0.1 + roll)*0.5;
            imageStore(destTex, storePos, vec4(1.0-globalCoef*localCoef, 0.0, 0.0, 0.0));
        }
    }

    GLSL ComputeGeometry {
        // Original VBOs would still be bound as readonly SSBOs

        // Via: https://lingtorp.com/2018/12/05/OpenGL-SSBO-indirect-drawing.html

        // Same as the OpenGL defined struct: DrawElementsIndirectCommand
        struct DrawCommand {
            uint count;         // Num elements (vertices)
            uint instanceCount; // Number of instances to draw (a.k.a primcount)
            uint firstIndex;    // Specifies a byte offset (cast to a pointer type) into the buffer bound to GL_ELEMENT_ARRAY_BUFFER to start reading indices from.
            uint baseVertex;    // Specifies a constant that should be added to each element of indices​ when chosing elements from the enabled vertex arrays.
            uint baseInstance;  // Specifies the base instance for use in fetching instanced vertex attributes.
        };

        // Command buffer backed by an SSBO
        layout(std140, binding = 0) writeonly buffer DrawCommandsBlock {
            DrawCommand draw_commands[];
        };

        // Need a write to a vertex/triangle buffer here as well.
        // Maybe there's an automatic secondary compute that reads
        // those buffer sizes and generates the indirect array call?

        const uint idx = gl_LocalInvocationID.x; // Compute space is 1D where x in [0, N)
        draw_commands[idx].count = 25350;        // sphere.indices.size(); # of indices in the mesh (GL_ELEMENTS_ARRAY)
        draw_commands[idx].instanceCount = visible ? 1 : 0;
        draw_commands[idx].baseInstance = 0;     // See above
        draw_commands[idx].baseVertex = 0;       // See above
    }

    // You may have multiple named techniques, but 
    // there must always be a `Main`.
    Technique Main {
        // A technique may define multiple passes
        Pass {
            // All are optional except Vertex & Fragment.

            // ProceduralMesh will be fed the mesh data and
            // is expected to generate new vertices/triangles.
            // Invocations are triangle indices
            // ProceduralMesh = MyComputeMesh

            // ProceduralTexture is fed mesh data but outputs
            // pixels of a texture - each invocation to a pixel index.
            // TODO: How do I specify output texture size/format?
            // ProceduralTexture = (Common, MyComputeTex)

            Vertex = (Common, MyVS)
            // TessellationControl = MyTCS
            // TessellationEvaluation = MyTES
            Geometry = MyGS
            Fragment = (Common, MyFS)
        }
    }

    // Shadowing (from the POV of light sources) has 
    // its own technique. If not specified, it will use
    // the Main technique. 
    Technique Shadow {
        Pass {
            Vertex = MyVS
            Fragment = ShadowFS
        }
    }
}

/*
    Internal changes to make:
    https://stackoverflow.com/questions/4635913/explicit-vs-automatic-attribute-location-binding-for-opengl-shaders

    Bind attributes to explicit locations and use
    those locations while binding buffers so that we 
    have a consistent location regardless of what 
    shader program is being used - so we don't need
    to rebuild the VAO per-program (in theory... in 
    practice I have no idea)
*/
