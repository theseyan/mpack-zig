const build_options = @import("mpack_build_opts");

const c = @cImport({
    @cDefine("MPACK_DEBUG", (if(build_options.debug == true) "1" else "0"));
    @cDefine("MPACK_STRINGS", (if(build_options.debug == true) "1" else "0"));
    @cDefine("MPACK_BUILDER", (if(build_options.builder_api == true) "1" else "0"));
    @cDefine("MPACK_EXPECT", (if(build_options.expect_api == true) "1" else "0"));
    @cDefine("MPACK_EXTENSIONS", "1");
    @cDefine("MPACK_OPTIMIZE_FOR_SIZE", "0");
    
    if (build_options.use_mimalloc) {
        @cInclude("mimalloc-override.h");
    }

    @cInclude("mpack.h");
});

pub usingnamespace c;