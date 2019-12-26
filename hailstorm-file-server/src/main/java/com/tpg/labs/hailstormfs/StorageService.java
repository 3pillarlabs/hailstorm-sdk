package com.tpg.labs.hailstormfs;

import org.springframework.core.io.Resource;

import java.io.FileNotFoundException;
import java.io.IOException;

public interface StorageService {

    /**
     * Saves the file to storage.
     *
     * @param fileMetaData
     * @param fileTransferDelegate
     * @return stored file URI
     * @throws IOException
     */
    String saveFile(FileMetaData fileMetaData, FileTransferDelegate fileTransferDelegate) throws IOException;

    /**
     * Delete a file
     *
     * @param fileId
     */
    void deleteFile(String fileId);

    /**
     * Get a file by Id and name
     *
     * @param fileId
     * @param fileName
     * @return
     * @throws FileNotFoundException
     */
    Resource getFile(String fileId, String fileName) throws FileNotFoundException;
}
