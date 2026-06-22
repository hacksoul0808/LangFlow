import { useTranslation } from "react-i18next";
import ForwardedIconComponent from "@/components/common/genericIconComponent";
import { useCustomNavigate } from "@/customization/hooks/use-custom-navigate";
import useFlowStore from "@/stores/flowStore";

const ButtonLabel = () => {
  const { t } = useTranslation();
  return <span className="font-normal text-mmd">{t("misc.playground")}</span>;
};

const PlaygroundButton = () => {
  const navigate = useCustomNavigate();
  const currentFlowId = useFlowStore((state) => state.currentFlow?.id);

  return (
    <button
      type="button"
      className="relative inline-flex h-8 w-auto items-center justify-start gap-1.5 rounded bg-muted px-2 text-sm font-normal text-foreground hover:bg-secondary-hover"
      data-testid="playground-btn-flow"
      onClick={() => {
        if (currentFlowId) {
          window.localStorage.setItem("lf_playground_last_flow_id", currentFlowId);
        }
        navigate("/playground");
      }}
    >
      <ForwardedIconComponent name="Play" className="h-4 w-4" />
      <ButtonLabel />
    </button>
  );
};

export default PlaygroundButton;
