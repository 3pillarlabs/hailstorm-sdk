package com.tpg.labs.hailstormfs;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.ApplicationArguments;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.util.FileSystemUtils;

import javax.validation.constraints.NotNull;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Stream;

import static com.tpg.labs.hailstormfs.FileMetaData.calculateHash;

@Service
public class LocalStorageServiceImpl implements StorageService, InitializingBean {

    static final String INFO_DIR = "information";
    static final String STORAGE_DIR = "storage";

    private static final String DEFAULT_BASE_PATH = "/hailstorm";
    private static final String BASE_PATH_OPTION = "basePath";

    String baseURI = DEFAULT_BASE_PATH;

    private final Logger logger = LoggerFactory.getLogger(this.getClass());
    private ApplicationArguments applicationArguments;
    private File storagePath;
    private File infoPath;

    @Autowired
    public void setApplicationArguments(ApplicationArguments applicationArguments) {
        logger.debug("{}, {}",
                applicationArguments.getOptionNames(),
                applicationArguments.getOptionValues(BASE_PATH_OPTION));
        this.applicationArguments = applicationArguments;
    }

    public void setBaseURI(@NotNull String baseURI) {
        this.baseURI = baseURI;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        if (applicationArguments != null) {
            List<String> values = applicationArguments.getOptionValues(BASE_PATH_OPTION);
            String argBasePath = values != null && values.size() == 1 ? values.get(0) : null;
            if (argBasePath != null) {
                setBaseURI(argBasePath);
            }
        }

        File basePath = new File(baseURI);
        if (!basePath.exists()) {
            Files.createDirectories(basePath.toPath());
        }

        this.storagePath = Paths.get(baseURI, STORAGE_DIR).toAbsolutePath().toFile();
        if (!this.storagePath.exists()) {
            Files.createDirectory(this.storagePath.toPath());
        }

        this.infoPath = Paths.get(baseURI, INFO_DIR).toAbsolutePath().toFile();
        if (!this.infoPath.exists()) {
            Files.createDirectory(this.infoPath.toPath());
        }

        logger.info("File server with basePath: {}", baseURI);
    }

    @Override
    public String saveFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException {
        String fileId = storeFile(fileMetaData, fileTransferDelegate);
        indexFile(fileId, fileMetaData);
        return fileId;
    }

    private String storeFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException {
        String hash = calculateHash(fileMetaData);
        File dest = new File(storagePath, hash);
        if (!dest.exists()) {
            Files.createDirectories(dest.toPath());
        }

        fileTransferDelegate.doTransfer(new File(dest, fileMetaData.getOriginalName()));
        return hash;
    }

    private void indexFile(String fileId, FileMetaData fileMetaData) throws IOException {
        Path indexedPath = fileMetaData.getPathPrefix() == null ?
                Paths.get(infoPath.getAbsolutePath(), fileId) :
                Paths.get(infoPath.getAbsolutePath(), fileMetaData.getPathPrefix(), fileId);

        createIndex(fileId, fileMetaData, indexedPath);
    }

    private void createIndex(String fileId, FileMetaData fileMetaData, Path indexedPath) throws IOException {
        if (fileMetaData.getPathPrefix() != null) {
            if (!Files.exists(indexedPath)) {
                Files.createDirectories(indexedPath.getParent());
                Files.createFile(indexedPath);
            }

            Path reverseIndex = Paths.get(infoPath.getAbsolutePath(), fileId, fileMetaData.getPathPrefix());
            if (!Files.exists(reverseIndex)) {
                Files.createDirectories(reverseIndex.getParent());
                Files.createFile(reverseIndex);
            }
        } else {
            Files.createDirectories(indexedPath);
        }
    }

    @Override
    public String saveFile(FileMetaData fileMetaData,
                           FileTransferDelegate fileTransferDelegate,
                           String tag) throws IOException {

        String fileId = saveFile(fileMetaData, fileTransferDelegate);
        indexFileWithTag(fileId, fileMetaData, tag);
        return fileId;
    }

    private void indexFileWithTag(String fileId, FileMetaData fileMetaData, String tag) throws IOException {
        Path indexedPath = fileMetaData.getPathPrefix() == null ?
                Paths.get(infoPath.getAbsolutePath(), tag, fileId) :
                Paths.get(infoPath.getAbsolutePath(), fileMetaData.getPathPrefix(), tag, fileId);

        createIndex(fileId, fileMetaData, indexedPath);
    }

    @Override
    public void deleteFile(String fileId) throws IOException {
        File file = new File(storagePath, fileId);
        if (file.exists()) {
            FileSystemUtils.deleteRecursively(file);
            removeFromIndex(fileId);
        }
    }

    private void removeFromIndex(String fileId) throws IOException {
        removeFromIndex(fileId, null);
    }

    private void removeFromIndex(String fileId, String tag) throws IOException {
        File file = new File(infoPath, fileId);
        if (Files.list(file.toPath()).count() > 0L) {
            Files.list(file.toPath()).forEach(path -> {
                String prefix = path.toFile().getName();
                try {
                    if (tag != null) {
                        Files.delete(Paths.get(infoPath.getAbsolutePath(), prefix, tag, fileId));
                    }

                    Files.delete(Paths.get(infoPath.getAbsolutePath(), prefix, fileId));
                } catch (IOException e) {
                    logger.warn("Skipping {}: {}", path, e.getMessage());
                }
            });
        } else if (tag != null) {
            Files.delete(Paths.get(infoPath.getAbsolutePath(), tag, fileId));
        }

        FileSystemUtils.deleteRecursively(file.toPath());
    }

    @Override
    public void deleteFile(String fileId, String tag) throws IOException {
        File file = new File(storagePath, fileId);
        if (file.exists()) {
            FileSystemUtils.deleteRecursively(file.toPath());
            removeFromIndex(fileId, tag);
        }
    }

    @Override
    public Resource getFile(String fileId, String fileName) throws FileNotFoundException {
        File file = Paths.get(storagePath.getAbsolutePath(), fileId, fileName).toFile();
        if (!file.exists()) {
            throw new FileNotFoundException(String.format("Not found %s/%s", fileId, fileName));
        }

        return new FileSystemResource(file);
    }

    @Override
    public void removeFilesWithPrefix(String prefix) throws IOException {
        Path prefixPath = Paths.get(infoPath.getAbsolutePath(), prefix);
        if (!Files.exists(prefixPath)) {
            return;
        }

        Files.list(prefixPath).forEach(path -> {
            if (!Files.isDirectory(path)) {
                String fileId = path.toFile().getName();
                FileSystemUtils.deleteRecursively(new File(storagePath, fileId));
                FileSystemUtils.deleteRecursively(new File(infoPath, fileId));
            }
        });

        FileSystemUtils.deleteRecursively(Paths.get(infoPath.getAbsolutePath(), prefix));
    }

    @Override
    public Stream<Path> listPaths(String prefix) {
        Path prefixPath = Paths.get(infoPath.getAbsolutePath(), prefix);
        if (!Files.exists(prefixPath)) {
            return Stream.empty();
        }

        try {
            return Files.list(prefixPath)
                    .filter(path -> !Files.isDirectory(path))
                    .flatMap(this::getStoragePaths);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public Stream<Path> listPaths(String prefix, String tag) {
        Path prefixPath = Paths.get(infoPath.getAbsolutePath(), prefix);
        if (!Files.exists(prefixPath)) {
            return Stream.empty();
        }

        try {
            return Files.list(prefixPath)
                    .filter(path -> Files.isDirectory(path) && path.toFile().getName().equals(tag))
                    .flatMap(path -> {
                        try {
                            return Files.list(path);
                        } catch (IOException e) {
                            logger.warn("Skipping {}: {}", path, e.getMessage());
                        }

                        return Stream.empty();
                    })
                    .flatMap(this::getStoragePaths);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private Stream<? extends Path> getStoragePaths(Path path) {
        String fileId = path.toFile().getName();
        try {
            return Files.list(Paths.get(storagePath.getAbsolutePath(), fileId));
        } catch (IOException e) {
            logger.warn("Skipping {}: {}", path, e.getMessage());
        }

        return Stream.empty();
    }
}
