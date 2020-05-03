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
public class ReportFileServiceImpl implements ReportFileService {

    static final String REPORTS_TAG = "reports";

    private final StorageService localStorageService;

    @Autowired
    public ReportFileServiceImpl(StorageService localStorageService) {
        this.localStorageService = localStorageService;
    }

    @Override
    public String saveFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException {
        return localStorageService.saveFile(fileMetaData, fileTransferDelegate, REPORTS_TAG);
    }

    @Override
    public List<ReportMetaData> getReportMetaDataList(String prefix) throws IOException {
        Stream<ReportMetaData> stream = localStorageService
                .listPaths(prefix, REPORTS_TAG)
                .map(path -> new ReportMetaData(
                        path.getParent().getFileName().toString(), path.getFileName().toString()));

        return stream.collect(Collectors.toList());
    }

    @Override
    public Resource getReport(String fileId, String fileName) throws FileNotFoundException {
        return localStorageService.getFile(fileId, fileName);
    }
}
