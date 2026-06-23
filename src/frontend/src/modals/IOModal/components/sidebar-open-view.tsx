import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import ThemeButtons from "@/components/core/appHeaderComponent/components/ThemeButtons";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useGetFlow } from "@/controllers/API/queries/flows/use-get-flow";
import { useCustomNavigate } from "@/customization/hooks/use-custom-navigate";
import useFlowStore from "@/stores/flowStore";
import { useFolderStore } from "@/stores/foldersStore";
import useFlowsManagerStore from "@/stores/flowsManagerStore";
import { useMessagesStore } from "@/stores/messagesStore";
import { useVoiceStore } from "@/stores/voiceStore";
import type { FlowType } from "@/types/flow";
import { cn } from "@/utils/utils";
import IconComponent from "../../../components/common/genericIconComponent";
import type { SidebarOpenViewProps } from "../types/sidebar-open-view";
import SessionSelector from "./IOFieldView/components/session-selector";

export const SidebarOpenView = ({
  sessions,
  setSelectedViewField,
  setvisibleSession,
  handleDeleteSession,
  visibleSession,
  selectedViewField,
  playgroundPage,
  showProjectWorkflows,
  showSettingsSection,
  setActiveSession,
}: SidebarOpenViewProps) => {
  const { t } = useTranslation();
  const [openMenuSession, setOpenMenuSession] = useState<string | null>(null);
  const navigate = useCustomNavigate();
  const { mutateAsync: getFlow } = useGetFlow();
  const setCurrentFlow = useFlowsManagerStore((state) => state.setCurrentFlow);
  const setIsLoading = useFlowsManagerStore((state) => state.setIsLoading);
  const currentFlowId = useFlowsManagerStore((state) => state.currentFlowId);
  const flows = useFlowsManagerStore((state) => state.flows);
  const folders = useFolderStore((state) => state.folders);

  const setNewSessionCloseVoiceAssistant = useVoiceStore(
    (state) => state.setNewSessionCloseVoiceAssistant,
  );

  const setNewChatOnPlayground = useFlowStore(
    (state) => state.setNewChatOnPlayground,
  );

  const [expandedFolderIds, setExpandedFolderIds] = useState<
    Record<string, boolean>
  >({});

  const flowsByFolder = useMemo(() => {
    const grouped = new Map<string, { name: string; flows: FlowType[] }>();
    const validFlows = (flows ?? []).filter(
      (flow) => flow.is_component !== true,
    );

    for (const flow of validFlows) {
      const folderId = flow.folder_id ?? "unassigned";
      if (folderId === "unassigned") continue;
      const folderName =
        folders.find((f) => f.id === folderId)?.name ??
        t("mainPage.myCollection") ??
        "项目";

      const existing = grouped.get(folderId);
      if (existing) existing.flows.push(flow);
      else grouped.set(folderId, { name: folderName, flows: [flow] });
    }

    return Array.from(grouped.entries()).map(([folderId, value]) => ({
      folderId,
      folderName: value.name,
      flows: value.flows ?? [],
    }));
  }, [flows, folders, t]);

  const displaySessions = sessions.length > 0 ? sessions : [currentFlowId];

  const handleSelectFlow = async (flowId: string) => {
    if (flowId === currentFlowId) return;
    setIsLoading(true);
    try {
      const flow = await getFlow({ id: flowId });
      setCurrentFlow(flow);
      window.localStorage.setItem("lf_playground_last_flow_id", flowId);
    } finally {
      setIsLoading(false);
    }
  };

  const handleNewChatForFlow = async (flowId: string) => {
    if (flowId !== currentFlowId) {
      await handleSelectFlow(flowId);
    }
    setvisibleSession(undefined);
    setSelectedViewField(undefined);
    setNewSessionCloseVoiceAssistant(true);
    setNewChatOnPlayground(true);
  };

  return (
    <>
      <div className="flex h-full flex-col px-2">
        <div className="flex flex-col gap-4">
          <Button
            data-testid="new-chat"
            variant="ghost"
            className="justify-start gap-2 px-2 py-2 hover:bg-secondary-hover"
            onClick={() => {
              setvisibleSession(undefined);
              setSelectedViewField(undefined);
              setNewSessionCloseVoiceAssistant(true);
              setNewChatOnPlayground(true);
            }}
          >
            <IconComponent name="Plus" className="h-[18px] w-[18px] text-ring" />
            <div className="text-mmd font-normal">{t("chat.newChat")}</div>
          </Button>
        </div>

        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto pt-4 custom-scroll">
          {showProjectWorkflows && (
            <div className="flex flex-col gap-2">
              <div className="flex items-center gap-2 px-2">
                <IconComponent
                  name="Folder"
                  className="h-[18px] w-[18px] text-ring"
                />
                <div className="text-mmd font-normal">项目</div>
              </div>
              <div className="flex flex-col gap-1">
                {flowsByFolder.map(({ folderId, folderName, flows }) => {
                  const expanded =
                    expandedFolderIds[folderId] ??
                    (flowsByFolder.length === 1 ? true : false);

                  return (
                    <div key={folderId} className="flex flex-col">
                      <div className="group flex items-center rounded-md hover:bg-secondary-hover">
                        <button
                          type="button"
                          className="flex h-8 min-w-0 flex-1 items-center gap-2 px-2 text-left text-mmd font-normal"
                          onClick={() => {
                            setExpandedFolderIds((prev) => ({
                              ...prev,
                              [folderId]: !expanded,
                            }));
                          }}
                        >
                          <IconComponent
                            name={expanded ? "ChevronDown" : "ChevronRight"}
                            className="h-4 w-4 shrink-0"
                          />
                          <div className="min-w-0 flex-1 truncate">
                            {folderName}
                          </div>
                        </button>

                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <button
                              type="button"
                              className="invisible mr-1 flex h-8 w-8 items-center justify-center rounded-md hover:bg-secondary-hover group-hover:visible"
                            >
                              <IconComponent
                                name="ChevronDown"
                                className="h-4 w-4 text-ring"
                              />
                            </button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent side="right" align="start">
                            <DropdownMenuItem
                              onSelect={() => navigate(`/all/folder/${folderId}`)}
                            >
                              打开项目
                            </DropdownMenuItem>
                            <DropdownMenuSeparator />
                            {flows.map((flow) => (
                              <DropdownMenuItem
                                key={flow.id}
                                onSelect={() => navigate(`/flow/${flow.id}/`)}
                              >
                                打开 {flow.name}
                              </DropdownMenuItem>
                            ))}
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>

                      {expanded && (
                        <div className="flex flex-col gap-1 pl-6">
                          {flows.map((flow) => (
                            <div
                              key={flow.id}
                              className={cn(
                                "group flex items-center rounded-md hover:bg-secondary-hover",
                                flow.id === currentFlowId && "bg-secondary-hover",
                              )}
                            >
                              <button
                                type="button"
                                className={cn(
                                  "flex h-8 min-w-0 flex-1 items-center gap-2 px-2 text-left text-mmd font-normal",
                                  flow.id === currentFlowId && "font-semibold",
                                )}
                                onClick={() => handleSelectFlow(flow.id)}
                              >
                                <IconComponent
                                  name={flow.icon ?? "Workflow"}
                                  className="h-4 w-4 shrink-0 text-ring"
                                />
                                <div className="min-w-0 flex-1 truncate">
                                  {flow.name}
                                </div>
                              </button>

                              <button
                                type="button"
                                className="invisible mr-0.5 flex h-8 w-8 items-center justify-center rounded-md hover:bg-secondary-hover group-hover:visible"
                                onClick={() => navigate(`/flow/${flow.id}/`)}
                              >
                                <IconComponent
                                  name="ArrowRight"
                                  className="h-4 w-4 text-ring"
                                />
                              </button>

                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <button
                                    type="button"
                                    className="mr-1 flex h-8 w-8 items-center justify-center rounded-md hover:bg-secondary-hover"
                                  >
                                    <IconComponent
                                      name="ChevronDown"
                                      className="h-4 w-4 text-ring"
                                    />
                                  </button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent side="right" align="start">
                                  <DropdownMenuItem
                                    onSelect={() => handleNewChatForFlow(flow.id)}
                                  >
                                    新对话
                                  </DropdownMenuItem>
                                  <DropdownMenuItem
                                    onSelect={() => navigate(`/flow/${flow.id}/`)}
                                  >
                                    编辑工作流
                                  </DropdownMenuItem>
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between px-2">
              <div className="flex items-center gap-2">
                <IconComponent
                  name="MessagesSquare"
                  className="h-[18px] w-[18px] text-ring"
                />
                <div className="text-mmd font-normal">对话</div>
              </div>
            </div>

            <div className="flex flex-col">
              {displaySessions.map((session, index) => (
                <SessionSelector
                  setSelectedView={setSelectedViewField}
                  selectedView={selectedViewField}
                  key={index}
                  session={session}
                  playgroundPage={playgroundPage}
                  deleteSession={(session) => {
                    handleDeleteSession(session);
                    if (selectedViewField?.id === session) {
                      setSelectedViewField(undefined);
                    }
                  }}
                  updateVisibleSession={(session) => {
                    setvisibleSession(session);
                  }}
                  toggleVisibility={() => {
                    setvisibleSession(session);
                  }}
                  isVisible={visibleSession === session}
                  inspectSession={(session) => {
                    setSelectedViewField({
                      id: session,
                      type: "Session",
                    });
                  }}
                  setActiveSession={(session) => {
                    setActiveSession(session);
                  }}
                  menuOpen={openMenuSession === session}
                  onMenuOpenChange={(open) => {
                    setOpenMenuSession(open ? session : null);
                  }}
                />
              ))}
            </div>
          </div>
        </div>

        {showSettingsSection && (
          <div className="flex flex-col gap-2 border-t border-border px-2 py-4">
            <div className="flex items-center gap-2">
              <IconComponent
                name="Settings"
                className="h-[18px] w-[18px] text-ring"
              />
              <div className="text-mmd font-normal">设置</div>
            </div>
            <div className="flex items-center justify-between">
              <div className="text-sm">{t("modal.io.theme")}</div>
              <ThemeButtons />
            </div>
            <Button
              variant="ghost"
              className="justify-start gap-2 px-2 hover:bg-secondary-hover"
              onClick={() => navigate("/settings/general")}
            >
              <IconComponent name="ExternalLink" className="h-4 w-4 text-ring" />
              <div className="text-mmd font-normal">打开设置</div>
            </Button>
          </div>
        )}
      </div>
    </>
  );
};
