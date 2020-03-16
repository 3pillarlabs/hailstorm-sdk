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
import java.nio.file.Paths;
import java.util.List;

import static com.tpg.labs.hailstormfs.FileMetaData.calculateHash;

@Service
public class LocalStorageServiceImpl implements StorageService, InitializingBean {

    private static final String DEFAULT_BASE_PATH = "/hailstorm";
    private static final String BASE_PATH_OPTION = "basePath";

    String baseURI = DEFAULT_BASE_PATH;

    private final Logger logger = LoggerFactory.getLogger(this.getClass());
    private ApplicationArguments applicationArguments;

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
    public void afterPropertiesSet() {
        if (applicationArguments != null) {
            List<String> values = applicationArguments.getOptionValues(BASE_PATH_OPTION);
            String argBasePath = values != null && values.size() == 1 ? values.get(0) : null;
            if (argBasePath != null) {
                setBaseURI(argBasePath);
            }
        }

        File basePath = new File(baseURI);
        if (!basePath.exists()) {
            basePath.mkdirs();
        }

        logger.info("File server with basePath: {}", baseURI);
    }

    @Override
    public String saveFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException {
        return saveFile(fileMetaData, fileTransferDelegate, baseURI);
    }

    @Override
    public String saveFile(FileMetaData fileMetaData,
                           FileTransferDelegate fileTransferDelegate,
                           String parentPath) throws IOException {

        String hash = calculateHash(fileMetaData);
        File dest = new File(parentPath, hash);
        if (!dest.exists()) {
            dest.mkdirs();
        }

        fileTransferDelegate.doTransfer(new File(dest, fileMetaData.getOriginalName()));
        return hash;
    }

    @Override
    public void deleteFile(String fileId) {
        File file = new File(baseURI, fileId);
        if (file.exists()) {
            FileSystemUtils.deleteRecursively(file);
        }
    }

    @Override
    public Resource getFile(String fileId, String fileName) throws FileNotFoundException {
        return getFile(fileId, fileName, baseURI);
    }

    @Override
    public Resource getFile(String fileId, String fileName, String parentPath) throws FileNotFoundException {
        File file = Paths.get(parentPath, fileId, fileName).toFile();
        if (!file.exists()) {
            throw new FileNotFoundException(String.format("Not found %s/%s", fileId, fileName));
        }

        return new FileSystemResource(file);
    }

    @Override
    public File makePath(String... components) {
        File path = Paths.get(baseURI, components).toFile();
        if (!path.exists()) {
            path.mkdirs();
        }

        return path;
    }
}
