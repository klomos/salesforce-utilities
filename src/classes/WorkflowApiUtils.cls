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

/**
 * This class provide utilities to setup Workflow using Metadata API.
 * 
 * It relies on Apex Wrapper for Salesforce Metadata API.
 * @see: https://github.com/financialforcedev/apex-mdapi
 * @see: https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_workflow.htm#WorkflowTimeTrigger
 */
public class WorkflowApiUtils {
	private static final String RECIPIENT_TYPE_USER = 'user';
    private static final String RECIPIENT_TYPE_ACCOUNT_OWNER = 'accountOwner';
    private static final String RECIPIENT_TYPE_CONTACT_LOOKUP = 'contactLookup';
    private static final String RECIPIENT_TYPE_CREATOR = 'creator';
    private static final String RECIPIENT_TYPE_ROLE = 'role';
    
    private static final String WF_TRIGGER_EVENT_CREATE_OR_EDIT = 'onCreateOrTriggeringUpdate';
    private static final String WF_TRIGGER_EVENT_CREATE = 'onCreateOnly';
    private static final String WF_TRIGGER_EVENT_ALL = 'onAllChanges';
    
    private static final String WF_TRIGGER_TIME_UNIT_DAY = 'Days';
    private static final String WF_TRIGGER_TIME_UNIT_HOUR = 'Hours';    
    
	private static final String WF_TRIGGER_ACTION_ALERT = 'Alert'; 
    private static final String WF_TRIGGER_ACTION_FIELD_UPDATE = 'FieldUpdate'; 
    
    /**
     * Create a webservice reference
     */ 
    public static MetadataService.MetadataPort createService()
    {
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        return service;
    }
    
    /**
     * WorkflowEmailRecipient can be a User, a Role, a Contact Lookup, an Account Owner or a Creator.
     * @recipientType - the type of recipient (see above)
     * @recipientValue - the recipient which applicable for a User (i.e. someone@abc.com) or a Role (i.e. contractor)
     */ 
    public static MetadataService.WorkflowEmailRecipient createEmailRecipient(String recipientType, String recipientValue) {
        MetadataService.WorkflowEmailRecipient recipient = new MetadataService.WorkflowEmailRecipient();
        recipient.type_x = recipientType;
        
        if (RECIPIENT_TYPE_USER.equalsIgnoreCase(recipientType) 
            	|| RECIPIENT_TYPE_ROLE.equalsIgnoreCase(recipientType)) {
            recipient.recipient = recipientValue;
        } else if (RECIPIENT_TYPE_CONTACT_LOOKUP.equalsIgnoreCase(recipientType)) {
            recipient.field = recipientValue;
        }
            
        return recipient;
    }
    
    /**
     * Create a Workflow Email Alert to send email to recipients (belongs to organization or external)
     * 
     * @service - service reference. It will instantiated if null 
     * @objectType - the SObject API Name of the object to attach the alert to
     * @alertName - unique name representing for the Email Alert
     * @emailTemplate - the email template name (API)
     * @recipients - (optional) list of internal recipients. This must be set if @additionalEmails is empty
     * @additionalEmails - (optional) list of email address to send the alert to. This must be set if @recipients is empty
     * 
     * Prerequisite: Must set the Default Workflow User to use as default sender.
     */ 
    public static void createWorkflowAlert(MetadataService.MetadataPort service, String objectType, String alertName, 
                                     String emailTemplate, MetadataService.WorkflowEmailRecipient[] recipients, 
                                     String[] additionalEmails) {
        if (service == null) {
            service = createService();
        }
        
        MetadataService.WorkflowAlert workflowAlert = new MetadataService.WorkflowAlert();
		workflowAlert.senderType = 'DefaultWorkflowUser';
		workflowAlert.description = alertName;
		workflowAlert.protected_x = false;                                         
        workflowAlert.fullName = objectType + '.' + alertName;
        workflowAlert.template = emailTemplate;
		
		if (additionalEmails != null && additionalEmails.size() > 0) {
			workflowAlert.ccEmails = additionalEmails;                                             
		}                                         

        if (recipients != null && recipients.size() > 0) {
            workflowAlert.recipients = recipients;
        }
        
        MetadataService.Metadata[] metadata = new MetadataService.Metadata[]{workflowAlert};
        List<MetadataService.SaveResult> results = service.createMetadata(metadata);
		handleSaveResults(results.get(0));
    }
    
    /**
     * Create a Workflow Rule with Time-Dependent workflow action to send Email Alert.
     * 
     * @service - service reference. It will instantiated if null 
     * @objectType - the SObject API Name of the object to attach the alert to
     * @ruleName - the name of Workflow Rule
     * @dependentField - dependent field to evaluate triggering time
     * @timeLength - how much time comparing to triggering time (i.e. 1 day before)
     * @timeUnit - unit which can be in 'Days' or 'Hours'
     * @triggerEvent - triggering event (i.e. on creation)
     * @actionName - the reference workflow action (i.e. an Email Alert, a Field Update, etc.)
     * @actionType - the action type (i.e. Alert, FieldUpdate)
     * @filterItems - filters for workflow rule. Note:Formula is also possible but there is a limit to filter Picklist so was not chosen
     * @booleanFilter - logical grouping filters
     */ 
    public static void createTimeDependentWorkflowRule(MetadataService.MetadataPort service, String objectType, String ruleName, 
                                                 String dependentField, Integer timeLength, String timeUnit, 
                                                 String triggerEvent, String actionName, String actionType, 
                                                 MetadataService.FilterItem[] filterItems, String booleanFilter) {
        if (service == null) {
            service = createService();
        }
        
        MetadataService.WorkflowActionReference workflowActionReference = new MetadataService.WorkflowActionReference();
        MetadataService.WorkflowRule workflowRule = new MetadataService.WorkflowRule();
        MetadataService.WorkflowTimeTrigger workflowTimeTrigger = new MetadataService.WorkflowTimeTrigger();
        
        workflowActionReference.name = actionName;
        workflowActionReference.type_x = actionType;
        
        workflowTimeTrigger.offsetFromField = objectType + '.' + dependentField;
        workflowTimeTrigger.timeLength = String.valueOf(timeLength);
        workflowTimeTrigger.workflowTimeTriggerUnit = timeUnit;
        workflowTimeTrigger.actions = new MetadataService.WorkflowActionReference[]{workflowActionReference};
     
        workflowRule.fullName = objectType + '.' + ruleName;
        workflowRule.active = true;
        workflowRule.description = ruleName;
        workflowRule.criteriaItems = filterItems;
		workflowRule.booleanFilter = (StringUtils.isEmpty(booleanFilter) ? null : booleanFilter);
        workflowRule.triggerType = triggerEvent;
        workflowRule.workflowTimeTriggers = new MetadataService.WorkflowTimeTrigger[]{workflowTimeTrigger};
            
        MetadataService.Metadata[] metadata = new MetadataService.Metadata[]{workflowRule};
        List<MetadataService.SaveResult> results = service.createMetadata(metadata);
		handleSaveResults(results.get(0));
    }
    
    /**
     * Create FilterItem which can be used in Workflow Rule filter.
     * FilterItem compiles an logical comparison expression which including a operand, operator and compared to value
     * 
     * @objectType - the SObject API Name of the object to attach the alert to. This is used to construct full field name
     * @fieldName - field name (API)
     * @operation - operation such as equals. contains
     * @value - the value to compare to
     */ 
    public static MetadataService.FilterItem createFilterItem(String objectType, String fieldName, String operation, String value) {
        MetadataService.FilterItem filter = new MetadataService.FilterItem();
		filter.field = objectType + '.' + fieldName;
        filter.operation = operation;
        filter.value = value;
        
        return filter;
    }
    
    /**
     * Simple result handler to log to debug console the processing results
     * 
     */ 
    public static void handleSaveResults(MetadataService.SaveResult saveResult) {
        if(saveResult==null || saveResult.success) {
            System.debug('SUCCESS ------');
            return;
        } else {
            if(saveResult.errors!=null)
            {
                List<String> messages = new List<String>();
                messages.add(
                    (saveResult.errors.size()==1 ? 'Error ' : 'Errors ') +
                    'occured processing component ' + saveResult.fullName + '.');
                for(MetadataService.Error error : saveResult.errors)
                    messages.add(
                        error.message + ' (' + error.statusCode + ').' +
                        ( error.fields!=null && error.fields.size()>0 ?
                         ' Fields ' + String.join(error.fields, ',') + '.' : '' ) );
                if(messages.size()>0)
                    System.debug('ERROR ++++ ' + messages);
            }
            if(!saveResult.success) {
                System.debug('Request failed with no specified error.');
            }
        }
    }
    
    /*
	public static void create1DayBeforeETAAlert() {
        MetadataService.WorkflowEmailRecipient[] recipients = new MetadataService.WorkflowEmailRecipient[]{};
        recipients.add(createEmailRecipient(RECIPIENT_TYPE_ROLE, 'Sea_Export_Operation_Manager'));
        recipients.add(createEmailRecipient(RECIPIENT_TYPE_ROLE, 'Sea_Export_Operation_Staff'));
        recipients.add(createEmailRecipient(RECIPIENT_TYPE_ROLE, 'Sea_Import_Operation_Manager'));
        recipients.add(createEmailRecipient(RECIPIENT_TYPE_ROLE, 'Sea_Import_Operation_Staff'));
        recipients.add(createEmailRecipient(RECIPIENT_TYPE_ROLE, 'Data_Entry_Manager'));
        recipients.add(createEmailRecipient(RECIPIENT_TYPE_ROLE, 'Data_Entry_Staff'));
		
		createWorkflowAlert(null, 'CustomObject1__c', 'Check_if_Arrival_notice_is_not_sent_1_day_before ', 
                            'Alert_Email/oneDay_Ahead_of_ETA', recipients, null);

        MetadataService.FilterItem[] criteriaItems = new MetadataService.FilterItem[]{};
		criteriaItems.add(createFilterItem('CustomObject1__c', 'Custom__c', 'equals', '×(No)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'CarrierType__c', 'equals', '海上(SEA)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 A/N情報登録済み(A/N Data Registered)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 本船/フライト到着済(Arrived)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 トランジット本船/フライト出発済(Transit Departured)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 本船/フライト遅延(Delayed)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 本船/フライト運行中(On Voyage)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 本船/フライト出発済(Departured)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 ブッキング情報変更(Booking Info Changed)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 ブッキング情報入手(Booking Info Received)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 SWITCH B/L情報登録済み(Switch B/L Data Registered)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 SWITCH B/L情報待ち(Waiting for Switch B/L Data)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 B/L情報登録済み(B/L Data Registered)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 AFRデータファイリング済み(AFR Data Filed)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 Pre-Alertデータ入力済み(Pre-Alert Data Registered)'));
        criteriaItems.add(createFilterItem('CustomObject1__c', 'Status__c', 'equals', '輸入 出荷情報入手(Cargo Info Received)'));
        
        String booleanFilter = '1 AND 2 AND 3 AND (4 OR 5 OR 6 OR 7 OR 8 OR 9 OR 10 OR 11 OR 12 OR 13 OR 14 OR 15 OR 16)';
        
        createTimeDependentWorkflowRule(null, 'CustomObject1__c', '1 day before ETA if Status is not updated', 'ETA__c', 1, 
                                        WF_TRIGGER_TIME_UNIT_DAY, WF_TRIGGER_EVENT_CREATE_OR_EDIT, 
                                        'Check_if_Arrival_notice_is_not_sent_1_day_before', WF_TRIGGER_ACTION_ALERT, criteriaItems, booleanFilter);
    }
*/
}