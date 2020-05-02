package com.tpg.labs.hailstormfs;

import org.springframework.core.io.Resource;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.List;

public interface ReportFileService {

    /**
     * Saves the report to storage.
     *
     * @param fileMetaData
     * @param fileTransferDelegate
     * @return stored file URI
     * @throws IOException
     */
    String saveFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException;

    /**
     * Fetches list of reports stored in file service.
     *
     * File Ids are not part of the title.
     *
     * @param prefix
     * @return
     */
    List<ReportMetaData> getReportMetaDataList(String prefix) throws IOException;

    /**
     * Get the report file from file system.
     *
     * @param fileId
     * @param fileName
     * @return
     */
    Resource getReport(String fileId, String fileName) throws FileNotFoundException;
}
