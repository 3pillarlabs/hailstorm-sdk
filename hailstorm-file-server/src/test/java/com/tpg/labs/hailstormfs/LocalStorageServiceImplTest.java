package com.tpg.labs.hailstormfs;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationArguments;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.util.FileSystemUtils;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class LocalStorageServiceImplTest {

    private static final String TEST_BASE_URI = "/tmp/hailstorm/test/fs";

    StorageService service;

    @BeforeEach
    void clearTestBaseUri() {
        FileSystemUtils.deleteRecursively(new File(TEST_BASE_URI));
        FileSystemUtils.deleteRecursively(new File(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR));
        FileSystemUtils.deleteRecursively(new File(TEST_BASE_URI, LocalStorageServiceImpl.STORAGE_DIR));
    }

    @BeforeEach
    void createServiceInstance() throws Exception {
        service = new LocalStorageServiceImpl();
        ((LocalStorageServiceImpl) service).setBaseURI(TEST_BASE_URI);
        ((LocalStorageServiceImpl) service).afterPropertiesSet();
    }

    private FileMetaData createFileMetadata(String content, String prefix) {
        return new FileMetaData(
                "a.txt",
                "text/plain",
                (long) content.length(),
                new ByteArrayInputStream(content.getBytes())).withPathPrefix(prefix);
    }

    private FileMetaData createFileMetadata(long contentLength, InputStream is, String prefix) {
        return new FileMetaData("a.txt", "text/plain", contentLength, is).withPathPrefix(prefix);
    }

    @Test
    void shouldSaveFileWithPrefix() throws Exception {
        FileTransferDelegate delegate = mock(FileTransferDelegate.class);
        final String prefix = "cuckoo";
        FileMetaData fileMetaData = createFileMetadata("<jtl></jtl>", prefix);

        String savedFileId = service.saveFile(fileMetaData, delegate);
        assertNotNull(savedFileId);
        verify(delegate).doTransfer(any(File.class));
        final Path prefixInfoPath = Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, prefix);
        assertTrue(Files.exists(prefixInfoPath));
        Optional<Path> fileIdPathOpt = Files.list(prefixInfoPath).findFirst();
        assertTrue(fileIdPathOpt.isPresent());
        Path fileId = fileIdPathOpt.get();
        File storedFile = Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.STORAGE_DIR,
                fileId.toFile().getName()
        ).toFile();
        assertTrue(storedFile.exists());
        assertTrue(Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.INFO_DIR,
                fileId.toFile().getName()
        ).toFile().exists());
    }

    @Test
    void shouldSaveFileWithPrefixAndTag() throws Exception {
        FileTransferDelegate delegate = mock(FileTransferDelegate.class);
        final String prefix = "cuckoo";
        final String tag = "reports";
        FileMetaData fileMetaData = createFileMetadata("<jtl></jtl>", prefix);

        String savedFileId = service.saveFile(fileMetaData, delegate, tag);
        assertNotNull(savedFileId);
        verify(delegate).doTransfer(any(File.class));

        final Path prefixInfoPath = Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, prefix);
        assertTrue(Files.exists(prefixInfoPath));
        Optional<Path> prefixFileIdPathOpt = Files
                .list(prefixInfoPath)
                .filter(path -> !Files.isDirectory(path))
                .findFirst();
        assertTrue(prefixFileIdPathOpt.isPresent());

        Path fileId = prefixFileIdPathOpt.get();
        File storedFile = Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.STORAGE_DIR,
                fileId.toFile().getName()
        ).toFile();
        assertTrue(storedFile.exists());
        assertTrue(Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.INFO_DIR,
                fileId.toFile().getName()
        ).toFile().exists());

        final Path prefixTagInfoPath = Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, prefix, tag);
        assertTrue(Files.exists(prefixTagInfoPath));

        Optional<Path> prefixTagFileIdPathOpt = Files.list(prefixTagInfoPath).findFirst();
        assertTrue(prefixTagFileIdPathOpt.isPresent());

        Path prefixTagFileId = prefixTagFileIdPathOpt.get();
        assertEquals(fileId.toFile().getName(), prefixTagFileId.toFile().getName());
    }

    @Test
    void shouldSaveFileWithoutPrefix() throws Exception {
        FileTransferDelegate delegate = mock(FileTransferDelegate.class);
        FileMetaData fileMetaData = createFileMetadata("<jtl></jtl>", null);

        String savedFileId = service.saveFile(fileMetaData, delegate);
        assertNotNull(savedFileId);
        verify(delegate).doTransfer(any(File.class));

        final Path prefixInfoPath = Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR);
        Optional<Path> fileIdPathOpt = Files.list(prefixInfoPath).findFirst();
        assertTrue(fileIdPathOpt.isPresent());
        Path fileId = fileIdPathOpt.get();
        File storedFile = Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.STORAGE_DIR,
                fileId.toFile().getName()
        ).toFile();
        assertTrue(storedFile.exists());

        assertTrue(Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.INFO_DIR,
                fileId.toFile().getName()
        ).toFile().exists());
    }

    @Test
    void shouldSaveTaggedFileWithoutPrefix() throws Exception {
        FileTransferDelegate delegate = mock(FileTransferDelegate.class);
        final String tag = "reports";
        FileMetaData fileMetaData = createFileMetadata("<jtl></jtl>", null);

        String savedFileId = service.saveFile(fileMetaData, delegate, tag);
        assertNotNull(savedFileId);
        verify(delegate).doTransfer(any(File.class));

        final Path prefixInfoPath = Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR);
        Optional<Path> prefixFileIdPathOpt = Files.list(prefixInfoPath).findFirst();
        assertTrue(prefixFileIdPathOpt.isPresent());

        Path fileId = prefixFileIdPathOpt.get();
        File storedFile = Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.STORAGE_DIR,
                fileId.toFile().getName()
        ).toFile();
        assertTrue(storedFile.exists());
        assertTrue(Paths.get(
                TEST_BASE_URI,
                LocalStorageServiceImpl.INFO_DIR,
                fileId.toFile().getName()
        ).toFile().exists());

        final Path prefixTagInfoPath = Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, tag);
        assertTrue(Files.exists(prefixTagInfoPath));

        Optional<Path> prefixTagFileIdPathOpt = Files.list(prefixTagInfoPath).findFirst();
        assertTrue(prefixTagFileIdPathOpt.isPresent());

        Path prefixTagFileId = prefixTagFileIdPathOpt.get();
        assertEquals(fileId.toFile().getName(), prefixTagFileId.toFile().getName());
    }

    @Test
    void shouldSaveSameFile() throws Exception {
        final FileTransferDelegate delegate = mock(FileTransferDelegate.class);
        final String prefix = "cuckoo";
        final FileMetaData fileMetaData = createFileMetadata(39L,
                new ClassPathResource("local_file_fixture.txt").getInputStream(), prefix);

        service.saveFile(fileMetaData, delegate);
        assertDoesNotThrow(() -> service.saveFile(fileMetaData, delegate));
        assertDoesNotThrow(() -> service.saveFile(fileMetaData, delegate));
    }

    @Test
    void shouldDeleteFileWithPrefix() throws Exception {
        final String prefix = "cuckoo";
        String fileId = createPrefixedFile(prefix);

        service.deleteFile(fileId);
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.STORAGE_DIR, fileId).toFile().exists());
        assertDoesNotThrow(() -> service.deleteFile(fileId), "should not fail on deleting a deleted file");
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, prefix, fileId).toFile().exists());
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, fileId).toFile().exists());
    }

    private String createPrefixedFile(String prefix) throws IOException {
        FileMetaData fileMetaData = createFileMetadata("Worth lies in self", prefix);
        return service.saveFile(fileMetaData, (dest) -> {
            Writer writer = new FileWriter(dest);
            writer.write("Worth lies in self");
            writer.close();
        });
    }

    @Test
    void shouldDeleteFileWithPrefixAndTag() throws IOException {
        final String prefix = "cuckoo";
        final String tag = "reports";
        String fileId = createTaggedAndPrefixedFile(prefix, tag);

        service.deleteFile(fileId, tag);
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.STORAGE_DIR, fileId).toFile().exists());
        assertDoesNotThrow(() -> service.deleteFile(fileId), "should not fail on deleting a deleted file");
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, prefix, tag, fileId).toFile().exists());
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, fileId).toFile().exists());
    }

    private String createTaggedAndPrefixedFile(String prefix, String tag) throws IOException {
        FileMetaData fileMetaData = createFileMetadata("Worth lies in self", prefix);
        return service.saveFile(fileMetaData, (dest) -> {
            Writer writer = new FileWriter(dest);
            writer.write("Worth lies in self");
            writer.close();
        }, tag);
    }

    @Test
    void shouldDeleteFileWithoutPrefix() throws IOException {
        String fileId = createPrefixedFile(null);

        service.deleteFile(fileId);
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.STORAGE_DIR, fileId).toFile().exists());
        assertDoesNotThrow(() -> service.deleteFile(fileId), "should not fail on deleting a deleted file");
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, fileId).toFile().exists());
    }

    @Test
    void shouldDeleteTaggedFileWithoutPrefix() throws IOException {
        final String tag = "reports";
        String fileId = createTaggedAndPrefixedFile(null, tag);

        service.deleteFile(fileId, tag);
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.STORAGE_DIR, fileId).toFile().exists());
        assertDoesNotThrow(() -> service.deleteFile(fileId), "should not fail on deleting a deleted file");
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, tag, fileId).toFile().exists());
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, fileId).toFile().exists());
    }

    @Test
    void shouldLoadFileAsResource() throws Exception {
        final String content = "Worth lies in self";
        FileMetaData fileMetaData = createFileMetadata(content, "cuckoo");
        String fileId = createPrefixedFile("cuckoo");

        Resource resource = service.getFile(fileId, fileMetaData.getOriginalName());
        assertNotNull(resource);
    }

    @Test
    void shouldThrowExceptionIfResourceUnknown() {
        assertThrows(FileNotFoundException.class, () -> service.getFile("123", "a.txt"));
    }

    @Test
    void shouldListPathsByPrefix() throws IOException {
        final String prefix = "cuckoo";
        final String fileId = createPrefixedFile(prefix);
        final Stream<Path> pathStream = service.listPaths(prefix);
        Optional<Path> first = pathStream.findFirst();
        assertTrue(first.isPresent());
        assertEquals(first.get().getParent().toFile().getName(), fileId);
    }

    @Test
    void shouldListPathsByPrefixAndTag() throws IOException {
        final String prefix = "cuckoo";
        final String tag = "reports";
        final String fileId = createTaggedAndPrefixedFile(prefix, tag);
        final Stream<Path> pathStream = service.listPaths(prefix, tag);
        Optional<Path> first = pathStream.findFirst();
        assertTrue(first.isPresent());
        assertEquals(first.get().getParent().toFile().getName(), fileId);
    }

    @Test
    void shouldHaveEmptyListIfPrefixNotExist() {
        assertSame(service.listPaths("cuckoo").count(), 0L);
    }

    @Test
    void shouldHaveEmptyListIfTagNotExist() {
        assertSame(service.listPaths("cuckoo", "tagly").count(), 0L);
    }

    @Test
    void shouldRemovePathsByPrefix() throws IOException {
        final String prefix = "cuckoo";
        final String tag = "reports";
        final String fileId = createTaggedAndPrefixedFile(prefix, tag);
        service.removeFilesWithPrefix(prefix);
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.STORAGE_DIR, fileId).toFile().exists());
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, prefix, fileId).toFile().exists());
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, prefix, tag, fileId).toFile().exists());
        assertFalse(Paths.get(TEST_BASE_URI, LocalStorageServiceImpl.INFO_DIR, fileId).toFile().exists());
        assertDoesNotThrow(() -> service.removeFilesWithPrefix(prefix), "is idempotent");
    }

    @Test
    void shouldSetBaseUrlFromArguments() throws Exception {
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
                return Arrays.asList(TEST_BASE_URI);
            }

            @Override
            public List<String> getNonOptionArgs() {
                return null;
            }
        });

        ((LocalStorageServiceImpl) service).afterPropertiesSet();
        assertEquals(((LocalStorageServiceImpl) service).baseURI, TEST_BASE_URI);
    }
}
