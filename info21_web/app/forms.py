from django import forms
from django.core.exceptions import ValidationError


class CSVImportForm(forms.Form):
    csv_file = forms.FileField(label='Select a CSV file')


def check_status_values(value):
    if value not in ['Start', 'Success', 'Failure']:
        raise ValidationError(
            "incorrect check status: %(value)s",
            params={"value": value}
        )


class CheckStatusField(forms.CharField):
    default_validators = [check_status_values]


class RawInputForm(forms.Form):
    inp_query = forms.CharField(label="input sql-query")


class F1AddP2P(forms.Form):
    peer = forms.SlugField(label="peer nickname")
    checker = forms.SlugField(label="checker nickname")
    task = forms.SlugField(label="task id")
    status = CheckStatusField(label="check status")
    add_time = forms.TimeField(label="time")


class F2AddVerter(forms.Form):
    peer = forms.SlugField(label="peer nickname")
    status = CheckStatusField(label="check status")
    add_time = forms.TimeField(label="time")


class F5PeersNotLeaving(forms.Form):
    p_day = forms.DateField(label="date")


class F11PeersCompletedBlock(forms.Form):
    block_name = forms.SlugField(label="block")


class F13TwoBlocksStats(forms.Form):
    block_1 = forms.SlugField()
    block_2 = forms.SlugField()


class F14MostFriendlyPeers(forms.Form):
    number = forms.IntegerField(label="top N")


class F17ThreeTasks(forms.Form):
    task_1 = forms.SlugField()
    task_2 = forms.SlugField()
    task_3 = forms.SlugField()


class F19LuckyDays(forms.Form):
    number = forms.IntegerField(label="checks")


class F23CameEarly(forms.Form):
    early_time = forms.TimeField(label="time")
    num_times = forms.IntegerField(label="number of times")


class F24PeersExitedTimes(forms.Form):
    n_days = forms.IntegerField(label="number of days")
    m_times = forms.IntegerField(label="number of times")


class F26PeersExitedMinutes(forms.Form):
    n_minutes = forms.IntegerField(label="minutes")


fnc_forms = {1: F1AddP2P, 2: F2AddVerter, 5: F5PeersNotLeaving,
             11: F11PeersCompletedBlock, 13: F13TwoBlocksStats,
             14: F14MostFriendlyPeers, 17: F17ThreeTasks, 19: F19LuckyDays,
             23: F23CameEarly, 24: F24PeersExitedTimes,
             26: F26PeersExitedMinutes}
