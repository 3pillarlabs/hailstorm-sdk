package com.tpg.labs.hailstormfs;

import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Optional;

public class FileMetaDataBuilder {

    public static FileMetaData build(MultipartFile file, String prefix) throws IOException {
        return new FileMetaData(
                file.getOriginalFilename(),
                file.getContentType(),
                file.getSize(),
                file.getInputStream()).withPathPrefix(prefix);
    }
}
