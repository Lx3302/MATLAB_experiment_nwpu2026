function [file,folder,filterindex] = uigetfile(varargin)
global STATAPP_LIFECYCLE_UIGET_QUEUE;
if isempty(STATAPP_LIFECYCLE_UIGET_QUEUE), error('StatAppProbe:NoUigetResponse','No test uigetfile response queued.'); end
response=STATAPP_LIFECYCLE_UIGET_QUEUE{1}; STATAPP_LIFECYCLE_UIGET_QUEUE(1)=[];
file=response{1}; folder=response{2}; filterindex=1;
end
