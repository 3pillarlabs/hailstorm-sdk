package com.tpg.labs.hailstormfs;

import com.fasterxml.jackson.annotation.JsonIgnore;

import java.io.File;
import java.io.InputStream;
import java.util.Optional;
import java.util.StringJoiner;

public class FileMetaData {

    private String id;
    private final String originalName;
    private final String mimeType;
    private final Long size;
    private final InputStream inputStream;
    private String pathPrefix;

    public FileMetaData(String originalName, String mimeType, Long size, InputStream inputStream) {
        this.originalName = originalName;
        this.mimeType = mimeType;
        this.size = size;
        this.inputStream = inputStream;
    }

    public String getOriginalName() {
        return originalName;
    }

    public String getMimeType() {
        return mimeType;
    }

    public Long getSize() {
        return size;
    }

    @JsonIgnore
    public InputStream getInputStream() {
        return inputStream;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public FileMetaData withId(String id) {
        setId(id);
        return this;
    }

    public String getPathPrefix() {
        return pathPrefix;
    }

    public void setPathPrefix(String pathPrefix) {
        this.pathPrefix = pathPrefix;
    }

    public FileMetaData withPathPrefix(String pathPrefix) {
        setPathPrefix(pathPrefix);
        return this;
    }

    @Override
    public String toString() {
        return new StringJoiner(", ", FileMetaData.class.getSimpleName() + "[", "]")
                .add("id='" + id + "'")
                .add("originalName='" + originalName + "'")
                .add("mimeType='" + mimeType + "'")
                .add("size=" + size)
                .toString();
    }
}
