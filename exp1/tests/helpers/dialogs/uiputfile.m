function [file,folder,filterindex] = uiputfile(varargin)
global STATAPP_LIFECYCLE_UIPUT_QUEUE STATAPP_LIFECYCLE_CLOSE_DURING_PUT;
if isempty(STATAPP_LIFECYCLE_UIPUT_QUEUE), error('StatAppProbe:NoUiputResponse','No test uiputfile response queued.'); end
response=STATAPP_LIFECYCLE_UIPUT_QUEUE{1}; STATAPP_LIFECYCLE_UIPUT_QUEUE(1)=[];
if ~isempty(STATAPP_LIFECYCLE_CLOSE_DURING_PUT)
    uiFigure=STATAPP_LIFECYCLE_CLOSE_DURING_PUT;
    STATAPP_LIFECYCLE_CLOSE_DURING_PUT=[];
    closeCallback=uiFigure.CloseRequestFcn;
    feval(closeCallback,uiFigure,struct('EventName','CloseRequest'));
end
file=response{1}; folder=response{2}; filterindex=1;
end
