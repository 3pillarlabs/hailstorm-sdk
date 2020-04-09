package com.tpg.labs.hailstormfs;

import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationArguments;
import org.springframework.core.io.Resource;

import java.io.*;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class LocalStorageServiceImplTest {

    @Test
    void shouldSaveFile() throws Exception {
        FileTransferDelegate delegate = mock(FileTransferDelegate.class);
        StorageService service = new LocalStorageServiceImpl();
        ((LocalStorageServiceImpl) service).setBaseURI("/tmp/hailstorm/test/fs");
        ((LocalStorageServiceImpl) service).afterPropertiesSet();
        FileMetaData fileMetaData = new FileMetaData(
                "a.jmx",
                "text/xml",
                10L,
                new ByteArrayInputStream("<jtl></jtl>".getBytes()));

        String path = service.saveFile(fileMetaData, (dest) -> delegate.doTransfer(dest));

        assertNotNull(path);
        verify(delegate).doTransfer(any(File.class));
    }

    @Test
    void shouldSetBaseUrlFromArguments() {
        StorageService service = new LocalStorageServiceImpl();
        ((LocalStorageServiceImpl) service).setApplicationArguments(new ApplicationArguments() {
            @Override
            public String[] getSourceArgs() {
                return new String[0];
            }

            @Override
            public Set<String> getOptionNames() {
                return new HashSet<>(Arrays.asList("basePath"));
            }

            @Override
            public boolean containsOption(String name) {
                return true;
            }

            @Override
            public List<String> getOptionValues(String name) {
                return Arrays.asList("/hailstorm");
            }

            @Override
            public List<String> getNonOptionArgs() {
                return null;
            }
        });

        ((LocalStorageServiceImpl) service).afterPropertiesSet();
        assertEquals(((LocalStorageServiceImpl) service).baseURI, "/hailstorm");
    }

    @Test
    void shouldDeleteFile() throws Exception {
        final String baseURI = "/tmp/hailstorm/test/fs";
        StorageService service = new LocalStorageServiceImpl();
        ((LocalStorageServiceImpl) service).setBaseURI(baseURI);
        ((LocalStorageServiceImpl) service).afterPropertiesSet();
        final String content = "Worth lies in self";
        FileMetaData fileMetaData = new FileMetaData(
                "a.txt",
                "text/plain",
                (long) content.length(),
                new ByteArrayInputStream(content.getBytes()));

        String fileId = service.saveFile(fileMetaData, (dest) -> {
            Writer writer = new FileWriter(dest);
            writer.write(content);
            writer.close();
        });

        service.deleteFile(fileId);
        assertFalse(new File(baseURI, fileId).exists());
        assertDoesNotThrow(() -> service.deleteFile(fileId),
                "should not fail on deleting a deleted file");
    }

    @Test
    void shouldLoadFileAsResource() throws Exception {
        final String baseURI = "/tmp/hailstorm/test/fs";
        StorageService service = new LocalStorageServiceImpl();
        ((LocalStorageServiceImpl) service).setBaseURI(baseURI);
        ((LocalStorageServiceImpl) service).afterPropertiesSet();
        final String content = "Worth lies in self";
        FileMetaData fileMetaData = new FileMetaData(
                "a.txt",
                "text/plain",
                (long) content.length(),
                new ByteArrayInputStream(content.getBytes()));

        String fileId = service.saveFile(fileMetaData, (dest) -> {
            Writer writer = new FileWriter(dest);
            writer.write(content);
            writer.close();
        });

        Resource resource = service.getFile(fileId, fileMetaData.getOriginalName());
        assertNotNull(resource);
    }

    @Test
    void shouldThrowExceptionIfResourceUnknown() throws Exception {
        StorageService service = new LocalStorageServiceImpl();
        assertThrows(FileNotFoundException.class, () -> {
           service.getFile("123", "a.txt");
        });
    }
}
