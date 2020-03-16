import { JMeterFileUploadState } from "../NewProjectWizard/domain";

export function isUploadInProgress(file?: JMeterFileUploadState) {
  if (!file) {
    return;
  }

  return (file.uploadProgress !== undefined &&
    file.uploadProgress < 100 &&
    !(file.uploadError || file.validationErrors));
}
