package com.tpg.labs.hailstormfs;

import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Service
public class ReportFileServiceImpl implements ReportFileService, InitializingBean {

    public static final String REPORTS_DIR = "reports";

    private File baseLocation;
    private StorageService localStorageService;

    @Autowired
    public void setLocalStorageService(StorageService localStorageService) {
        this.localStorageService = localStorageService;
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        baseLocation = localStorageService.makePath(REPORTS_DIR);
    }

    @Override
    public String saveFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException {
        File dest = new File(baseLocation, fileMetaData.getPathPrefix());
        return localStorageService.saveFile(fileMetaData, fileTransferDelegate, dest.getAbsolutePath());
    }

    @Override
    public List<ReportMetaData> getReportMetaDataList(String prefix) throws IOException {
        Path startPath = Paths.get(baseLocation.getAbsolutePath(), prefix);
        if (!startPath.toFile().exists()) {
            return Collections.emptyList();
        }

        Stream<ReportMetaData> stream = Files.list(startPath)
                .flatMap(path -> {
                    try {
                        return Files.list(path);
                    } catch (IOException e) {
                        throw new RuntimeException(e);
                    }
                })
                .map(path -> new ReportMetaData(path.getParent().getFileName().toString(),
                        path.getFileName().toString()));

        return stream.collect(Collectors.toList());
    }

    @Override
    public Resource getReport(String prefix, String fileId, String fileName) throws FileNotFoundException {
        File dest = new File(baseLocation, prefix);
        return localStorageService.getFile(fileId, fileName, dest.getAbsolutePath());
    }
}
