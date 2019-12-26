package com.tpg.labs.hailstormfs;

import java.io.File;
import java.io.IOException;

public interface FileTransferDelegate {

    void doTransfer(File dest) throws IOException;
}
