import { FormikActions } from "formik";

export type FormikActionsHandler = (values: {[K: string]: any}, actions: FormikActions<{[K: string]: any}>) => void;
