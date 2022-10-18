CREATE OR REPLACE FUNCTION public.get_status_so(param_agency_id integer, param_external_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$    
DECLARE    
	vStatus text;
	vDTBudgetRevised timestamptz;
	vDTSentToPersonPaying timestamptz;
	vTradesman int;

	vStatusFinal text := '';

BEGIN    
	SELECT so.status,
	       so.datetime_budget_revised,
	       so.datetime_sent_to_person_paying,
	       so.tradesman_id
	  INTO vStatus,
	       vDTBudgetRevised,
	       vDTSentToPersonPaying,
	       vTradesman
	  FROM service_order so
	 WHERE so.agency_id = param_agency_id
	   AND so.external_id = cast(param_external_id as varchar)
	   AND so.stage in('order', 'budget', 'execution', 'cancelled', 'finished')
	ORDER BY so.created_at DESC
	LIMIT 1;

	vStatusFinal :=
 	case
		when vStatus in('budget_order_refused', 'order_opened') then 'allocateProvider'
		when vStatus = 'budget_negotiation' then 'waitApproveCounterProposal'
		when vStatus in('execution_budget_approved', 'execution_scheduled', 'execution_canceled') then 'waitExecutionService'
		when vStatus in('budget_order_selected', 'budget_order_viewed', 'budget_scheduled', 'budget_lost') then 'waitBudget'
		when vStatus in('order_opened', 'budget_under_analysis') then 'allocateProviderPreApproved'
		when vStatus = 'cancelled' then 'cancelled'
		when vStatus = 'budget_under_analysis' then 'sendBudgetPayer'
		when vStatus = 'execution_budget_approved' then 'sendExecution'
		when vStatus = 'budget_under_analysis' then 'reviewBudget'
		when vStatus in('execution_registered', 'execution_proofs_sent', 'execution_invoice_sent', 'service_finished_repproved') then 'serviceExecution'
		when vStatus = 'service_finished' then 'waitApproveFinish'
		when vStatus = 'finished' then 'serviceOrderFinish'
		when vStatus = 'budget_under_analysis' then 'waitApprovePayer'
	end;

	if (vStatus = 'waitApprovePayer' and vDTSentToPersonPaying is null)
	   or (vStatus = 'sendBudgetPayer' and vDTBudgetRevised is not null and vDTSentToPersonPaying is null)
	   or (vStatus = 'reviewBudget' and vDTBudgetRevised is null)
	   or (vStatus = 'allocateProviderPreApproved' and vTradesman is null)
	then
    	vStatusFinal = '';
    end if;
	 
	 
RETURN vStatusFinal;
END;   
$function$
;