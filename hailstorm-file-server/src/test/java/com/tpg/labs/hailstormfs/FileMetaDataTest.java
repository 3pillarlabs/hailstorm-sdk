package com.tpg.labs.hailstormfs;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;

import static org.junit.jupiter.api.Assertions.*;

class FileMetaDataTest {

    @Test
    void shouldNotThrowOnToString() {
        final String content = "Hello World";
        FileMetaData fileMetaData = new FileMetaData(
                "a.txt",
                "text/plain",
                (long) content.length(),
                new ByteArrayInputStream(content.getBytes())
        );

        assertDoesNotThrow(fileMetaData::toString);
    }
}
