<template>
	<div class="px-12 py-8 space-y-8">
		<div class="flex items-center">
			<FeatherIcon name="calendar" class="h-7 w-7 text-gray-500 mr-2.5" />
			<span class="font-semibold text-2xl text-gray-500 mr-2">Roster:</span>
			<span class="font-semibold text-2xl">{{
				viewMode === "week" ? "Week View" : "Month View"
			}}</span>
			<div class="ml-auto space-x-2.5">
				<!-- Nordic: Week / Month switch -->
				<Button
					size="md"
					:variant="viewMode === 'week' ? 'solid' : 'subtle'"
					@click="setViewMode('week')"
				>
					Week
				</Button>
				<Button
					size="md"
					:variant="viewMode === 'month' ? 'solid' : 'subtle'"
					@click="setViewMode('month')"
				>
					Month
				</Button>
				<Dropdown
					:options="VIEW_OPTIONS"
					:button="{
						label: 'View',
						iconRight: 'chevron-down',
						size: 'md',
					}"
				>
				</Dropdown>
				<Dropdown
					:options="[
						{
							label: 'Shift Assignment',
							onClick: () => {
								showShiftAssignmentDialog = true;
							},
						},
					]"
					:button="{
						label: 'Create',
						variant: 'solid',
						iconRight: 'chevron-down',
						size: 'md',
					}"
				/>
			</div>
		</div>
		<MonthViewHeader
			:firstOfMonth="periodStart"
			:numDays="numDays"
			:viewMode="viewMode"
			@updateFilters="updateFilters"
			@addToMonth="addToMonth"
		/>
		<!-- Nordic: no company required; staff of all companies the user may see are listed -->
		<MonthViewTable
			ref="monthViewTable"
			:firstOfMonth="periodStart"
			:numDays="numDays"
			:employees="employees.data || []"
			:employeeFilters="employeeFilters"
			:shiftFilters="shiftFilters"
		/>
	</div>
	<ShiftAssignmentDialog
		v-model="showShiftAssignmentDialog"
		:isDialogOpen="showShiftAssignmentDialog"
		:employees="employees.data"
		@fetchEvents="
			monthViewTable?.events.fetch();
			showShiftAssignmentDialog = false;
		"
	/>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from "vue";
import { Dropdown, FeatherIcon, createListResource } from "frappe-ui";

import { Dayjs } from "dayjs";

import { dayjs, goTo, raiseToast } from "../utils";
import MonthViewTable from "../components/MonthViewTable.vue";
import MonthViewHeader from "../components/MonthViewHeader.vue";
import ShiftAssignmentDialog from "../components/ShiftAssignmentDialog.vue";

export type EmployeeFilters = {
	[K in "status" | "company" | "department" | "branch" | "designation"]?: string;
};
export type ShiftFilters = {
	[K in "shift_type" | "shift_location"]?: string;
};

const monthViewTable = ref<InstanceType<typeof MonthViewTable>>();
const showShiftAssignmentDialog = ref(false);

// Nordic: the roster week runs Saturday to Friday
const rosterWeekStart = (date: Dayjs) => date.subtract((date.day() + 1) % 7, "d").startOf("D");
const viewMode = ref<"week" | "month">("week");
const periodStart = ref(rosterWeekStart(dayjs()));
const numDays = computed(() =>
	viewMode.value === "week" ? 7 : periodStart.value.daysInMonth(),
);

const setViewMode = (mode: "week" | "month") => {
	if (mode === viewMode.value) return;
	if (mode === "month") {
		periodStart.value = periodStart.value.add(3, "d").date(1).startOf("D");
	} else {
		const today = dayjs();
		periodStart.value = rosterWeekStart(
			today.isSame(periodStart.value, "month") ? today : periodStart.value,
		);
	}
	viewMode.value = mode;
};
const employeeFilters = reactive<EmployeeFilters>({
	status: "Active",
});
const shiftFilters = reactive<ShiftFilters>({});

const VIEW_OPTIONS = [
	"Shift Type",
	"Shift Location",
	"Shift Assignment",
	"Shift Schedule",
	"Shift Schedule Assignment",
].map((label) => ({
	label,
	onClick: () => goTo(`/app/${label.toLowerCase().split(" ").join("-")}`),
}));

const addToMonth = (change: number) => {
	periodStart.value =
		viewMode.value === "week"
			? periodStart.value.add(7 * change, "d")
			: periodStart.value.add(change, "M");
};

const updateFilters = (newFilters: EmployeeFilters & ShiftFilters) => {
	let employeeUpdated = false;
	(Object.entries(newFilters) as [keyof EmployeeFilters | keyof ShiftFilters, string][]).forEach(
		([key, value]) => {
			if (["shift_type", "shift_location"].includes(key)) {
				if (value) shiftFilters[key] = value;
				else delete shiftFilters[key];
				return;
			}

			if (value) employeeFilters[key] = value;
			else delete employeeFilters[key];
			employeeUpdated = true;
		},
	);
	if (employeeUpdated) employees.fetch();
};

// RESOURCES

const employees = createListResource({
	doctype: "Employee",
	fields: ["name", "employee_name", "designation", "image"],
	filters: employeeFilters,
	pageLength: 99999,
	onError(error: { messages: string[] }) {
		raiseToast("error", error.messages[0]);
	},
});
</script>
