/**
 * The MIT License (MIT)
 * 
 * Copyright (c) 2015 Klomos.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
public class SecurityValidator {
    public enum Permissions {P_READ, P_CREATE, P_EDIT, P_DELETE}
    
    public class ValidationResult {
        public List<String> errors {get; private set;}
        private boolean isSuccess = true;
        
        public ValidationResult() {
            errors = new List<String>();
        }
        
        public void addError(String errorMessage) {
            if (!StringUtils.isEmpty(errorMessage)) {
	            errors.add(errorMessage);
                isSuccess = false;
            }
        }
    }
    
    /**
     * This function is used to validate if the current user has the permission to interact on requested object.
     * 
     * @objectName - The API Name of the requested object
     * @permission - The requested permission (READ/CREATE/EDIT/DELETE)
     * 
     * @return - The validation result. If there is any violation, the error will be added and isSuccess = False.
     * If there is any system error such as the requested object does not exist, add error to validation result.
     */ 
    public static ValidationResult validateCRUD(String objectName, Permissions permission) {
        ValidationResult validationResult = new ValidationResult();
        
        try {
            Map<String, Schema.SObjectType> globalDescription = Schema.getGlobalDescribe();
            Schema.SObjectType objectType = globalDescription.get(objectName);
            Schema.DescribeSObjectResult result = objectType.getDescribe();
            
            if (Permissions.P_READ == permission && !result.isAccessible()) {
                validationResult.addError('Not allowed to read object: ' + objectName);
            } else if (Permissions.P_CREATE == permission && !result.isCreateable()) {
                validationResult.addError('Not allowed to create object: ' + objectName);
            } else if (Permissions.P_EDIT == permission && !result.isUpdateable()) {
                validationResult.addError('Not allowed to edit object: ' + objectName);
            } else if (Permissions.P_DELETE == permission && !result.isDeletable()) {
                validationResult.addError('Not allowed to delete object: ' + objectName);
            }
        } catch (Exception e) {
            validationResult.addError('ERROR: Encountered error while validating permission. [' + e.getMessage() + ']');
        }
        
        return validationResult;
    }
    
    /**
     * This function is used to validate if the current user has the permission to interact on requested fields.
     * 
     * @objectName - The API Name of the requested object
     * @requestedFields - The list of fields need to interact with
     * @permission - The requested permission (READ/CREATE/EDIT/DELETE)
     * 
     * @return - The validation result. If there is any violation, the error will be added and isSuccess = false.
     * If there is any system error such as the requested object does not exist, add error to validation result.
     */ 
    public static ValidationResult validateFLS(String objectName, Set<String> requestedFields, Permissions permission) {
        ValidationResult validationResult = new ValidationResult();
        
        try {
            Map<String, Schema.SObjectType> globalDescription = Schema.getGlobalDescribe();
            Schema.SObjectType objectType = globalDescription.get(objectName);
            Schema.DescribeSObjectResult result = objectType.getDescribe();
            Map<String, Schema.SObjectField> mapFields = result.fields.getMap();
            
            for (Schema.SObjectField field : mapFields.values()) {
                Schema.DescribeFieldResult fieldResult = field.getDescribe();
                
                if (requestedFields.contains(fieldResult.getName())) {
                    if (Permissions.P_READ == permission && !fieldResult.isAccessible()) {
                        validationResult.addError('Not allowed to read field: ' + objectName + '.' +fieldResult.getName());    
                    } else if (Permissions.P_CREATE == permission && !fieldResult.isCreateable()) {
                        validationResult.addError('Not allowed to create field: ' + objectName + '.' +fieldResult.getName()); 
                    } else if (Permissions.P_EDIT == permission && !fieldResult.isUpdateable()) {
                        validationResult.addError('Not allowed to edit field: ' + objectName + '.' +fieldResult.getName()); 
                    }
                }
            }
        } catch (Exception e) {
            validationResult.addError('ERROR: Encountered error while validating permission. [' + e.getMessage() + ']');
        }
        
        return validationResult;
    }
}