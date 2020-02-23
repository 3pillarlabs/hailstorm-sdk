package com.tpg.labs.hailstormfs;

import org.springframework.core.io.Resource;

import java.io.File;
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
     * Saves the file to storage under the <code>parentPath</code> directory.
     *
     * @param fileMetaData
     * @param fileTransferDelegate
     * @param parentPath
     * @return
     * @throws IOException
     */
    String saveFile(FileMetaData fileMetaData,
                    FileTransferDelegate fileTransferDelegate,
                    String parentPath) throws IOException;

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

    /**
     * Get a file by Id and name under a given path.
     *
     * @param fileId
     * @param fileName
     * @param parentPath
     * @return
     * @throws FileNotFoundException
     */
    Resource getFile(String fileId, String fileName, String parentPath) throws FileNotFoundException;

    /**
     * Make the path components if they do not exist
     *
     * @param components
     * @return the created path
     */
    File makePath(String... components);
}
