import { useEffect, useMemo, useRef } from "react";
import AlertDisplayArea from "@/alerts/displayArea";
import { useGetRefreshFlowsQuery } from "@/controllers/API/queries/flows/use-get-refresh-flows-query";
import { useGetFlow } from "@/controllers/API/queries/flows/use-get-flow";
import { CustomIOModal } from "@/customization/components/custom-new-modal";
import useFlowStore from "@/stores/flowStore";
import useFlowsManagerStore from "@/stores/flowsManagerStore";

const LAST_FLOW_ID_KEY = "lf_playground_last_flow_id";

export const PlaygroundWorkbenchPage = () => {
  const { mutateAsync: getFlow } = useGetFlow();
  const setPlaygroundPage = useFlowStore((state) => state.setPlaygroundPage);
  const setCurrentFlow = useFlowsManagerStore((state) => state.setCurrentFlow);
  const setIsLoading = useFlowsManagerStore((state) => state.setIsLoading);
  const flows = useFlowsManagerStore((state) => state.flows);
  const currentFlowId = useFlowsManagerStore((state) => state.currentFlowId);
  const currentFlow = useFlowsManagerStore((state) => state.currentFlow);
  const lastAppliedFlowIdRef = useRef<string | null>(null);

  useGetRefreshFlowsQuery(
    { get_all: true, header_flows: true },
    { enabled: true },
  );

  useEffect(() => {
    setPlaygroundPage(false);
  }, [setPlaygroundPage]);

  const candidateFlowIds = useMemo(() => {
    if (!flows) return [];
    return flows
      .filter((flow) => flow.is_component !== true)
      .map((flow) => flow.id);
  }, [flows]);

  const defaultFlowId = useMemo(() => {
    if (candidateFlowIds.length === 0) return null;

    const stored = window.localStorage.getItem(LAST_FLOW_ID_KEY);
    if (stored && candidateFlowIds.includes(stored)) return stored;

    return candidateFlowIds[0];
  }, [candidateFlowIds]);

  useEffect(() => {
    if (!defaultFlowId) return;
    if (lastAppliedFlowIdRef.current === defaultFlowId) return;
    if (currentFlowId === defaultFlowId && currentFlow?.data) {
      lastAppliedFlowIdRef.current = defaultFlowId;
      return;
    }

    const load = async () => {
      setIsLoading(true);
      try {
        const flow = await getFlow({ id: defaultFlowId });
        setCurrentFlow(flow);
        window.localStorage.setItem(LAST_FLOW_ID_KEY, defaultFlowId);
        lastAppliedFlowIdRef.current = defaultFlowId;
      } finally {
        setIsLoading(false);
      }
    };

    load();
  }, [
    defaultFlowId,
    currentFlowId,
    currentFlow?.data,
    getFlow,
    setCurrentFlow,
    setIsLoading,
  ]);

  useEffect(() => {
    document.title = currentFlow?.name || "Langflow";
  }, [currentFlow?.name]);

  return (
    <div className="flex h-full w-full flex-col items-center justify-center align-middle">
      <div className="fixed bottom-4 left-4 z-[999]">
        <AlertDisplayArea />
      </div>
      {defaultFlowId && (
        <CustomIOModal
          open={true}
          setOpen={() => {}}
          isPlayground
          showProjectWorkflows
          showSettingsSection
          showPublishOptions={false}
        >
          <></>
        </CustomIOModal>
      )}
    </div>
  );
};

export default PlaygroundWorkbenchPage;
