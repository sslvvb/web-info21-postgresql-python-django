from django.shortcuts import render, redirect, get_object_or_404

from app.models import get_table_names

from django.apps import apps

from .forms import RawInputForm, fnc_forms, CSVImportForm

from django.forms import modelform_factory

from django.db import connection, ProgrammingError, IntegrityError

from io import StringIO

from json import loads

from django.http import HttpResponse, HttpResponseBadRequest, Http404

from django.contrib import messages

import csv

import logging

logger = logging.getLogger(__name__)


def _get_model_class_or_404(table_name):
    try:
        return apps.get_model(app_label='app', model_name=table_name)
    except LookupError:
        logger.warning(f"Table '{table_name}' not found or is invalid.")
        raise Http404(f"Table '{table_name}' not found or is invalid.")


def main(request):
    logger.info("Visit home page.")
    return render(request, 'main.html')


def data(request):
    logger.info("Visit data page.")
    valid_tables: list = ['peers', 'checks', 'p2p', 'xp', 'friends',
                          'recommendations', 'tasks', 'timetracking',
                          'transferredpoints', 'verter']
    tables: list = get_table_names()
    filtered_tables: list = [value for value in tables if
                             value in valid_tables]
    return render(request, 'data.html', {'tables': filtered_tables})


def table_data(request, table_name):
    logger.info(f"Visit {table_name} table data page.")
    model_class = _get_model_class_or_404(table_name)
    fields = model_class._meta.fields  # pylint: disable=protected-access
    rows = model_class.objects.all()

    return render(request, 'table_data.html',
                  {'table_name': table_name, 'fields': fields,
                   'data': rows})


def create_row(request, table_name):
    logger.info(f"Visit {table_name} create row page.")
    model_class = _get_model_class_or_404(table_name)
    dynamic_form = modelform_factory(model_class, exclude=[])

    if request.method == 'POST':
        form = dynamic_form(request.POST)
        if form.is_valid():
            try:
                form.save()
                logger.info(f"SUCCESS: save row to {table_name}.")
                return redirect('table_data', table_name)
            except Exception as e:
                logger.warning(f"Could not insert data: {e}.")
                messages.error(request, f"Could not insert data: {e}")
    else:
        form = dynamic_form()

    return render(request, 'create_row.html',
                  {'form': form, 'table_name': table_name})


def edit_row(request, table_name, pk):
    logger.info(f"Visit {table_name} edit row page; pk = {pk}.")
    model_class = _get_model_class_or_404(table_name)
    obj_to_edit = get_object_or_404(model_class, pk=pk)
    dynamic_form = modelform_factory(model_class, exclude=[])

    if request.method == 'POST':
        form = dynamic_form(request.POST, instance=obj_to_edit)
        if form.is_valid():
            try:
                form.save()
                logger.info(
                    f"SUCCESS: edit row from {table_name} table; pk = {pk}.")
                return redirect('table_data', table_name)
            except Exception as e:
                logger.warning(f"Could not edit row from {table_name} table; "
                               f"pk = {pk}. Exception: {e}.")
                messages.error(request, "Could not update data.")
    else:
        form = dynamic_form(instance=obj_to_edit)

    return render(request, 'edit_row.html',
                  {'form': form, 'table_name': table_name})


def delete_row(request, table_name, pk):
    if request.method == 'POST':
        model_class = _get_model_class_or_404(table_name)
        obj_to_delete = get_object_or_404(model_class, pk=pk)

        try:
            obj_to_delete.delete()
            logger.info(
                f"SUCCESS: delete row from {table_name} table; pk = {pk}.")
            return redirect('table_data', table_name)
        except Exception as e:
            logger.warning(f"Could not delete row from {table_name} table; "
                           f"pk = {pk}. Exception: {e}.")
            messages.error(request, "Could not delete data.")

        return redirect('table_data', table_name)
    else:
        logger.warning(f"Invalid visit. Operation = delete; "
                       f"table = {table_name}; pk = {pk}.")
        return HttpResponseBadRequest("Invalid request method")


def clear_table(request, table_name):
    if request.method == 'POST':
        model_class = _get_model_class_or_404(table_name)
        model_class.objects.all().delete()
        logger.info(f"SUCCESS: clear {table_name} table.")
        return redirect('table_data', table_name)
    else:
        logger.warning(
            f"Invalid visit. Operation = clear table; table = {table_name}.")
        return HttpResponseBadRequest("Invalid request method")


def import_table(request, table_name):
    logger.info(f"Visit import to {table_name} table page.")
    if request.method == 'POST':
        model_class = _get_model_class_or_404(table_name)
        form = CSVImportForm(request.POST, request.FILES)
        if form.is_valid():
            csv_file = request.FILES['csv_file'].read().decode(
                'utf-8').splitlines()
            csv_reader = csv.reader(csv_file)
            next(csv_reader)

            try:
                for row in csv_reader:
                    if len(row):
                        instance = model_class(*row)
                        try:
                            instance.save()
                        except TypeError as e:
                            messages.error(request,
                                           f"Could not insert data: {e}.")
                            logger.warning(f"Could not insert data to "
                                           f"{table_name} table: {e}.")
            except Exception as e:
                messages.error(request, f"Error creating instance: {e}")
                logger.warning(
                    f"Error creating instance to {table_name} table: {e}.")
                return render(request, 'import.html',
                              {'form': form, 'table_name': table_name})

            logger.info("Import process to {table_name} table is complete.")
            return redirect('table_data', table_name)
    else:
        form = CSVImportForm()

    return render(request, 'import.html',
                  {'form': form, 'table_name': table_name})


def export_table(request, table_name):
    logger.info(f"Export {table_name} table to csv file.")
    model_class = _get_model_class_or_404(table_name)
    rows = model_class.objects.all()

    response = HttpResponse(content_type='text/csv')
    response[
        'Content-Disposition'] = f'attachment; filename="{table_name}.csv"'

    writer = csv.writer(response)

    header = [field.name for field in model_class._meta.fields]
    writer.writerow(header)

    for row in rows:
        row_data = [getattr(row, field) for field in header]
        writer.writerow(row_data)

    return response


def operations(request):
    logger.info('Visit operations page')
    form = None
    output = None
    table_header = None
    tab = request.GET.get('tab', 'default')
    fnum = request.GET.get('fnum', '')
    if tab not in ['raw', 'functions', 'default'] \
            or fnum != '' and (int(fnum) < 1 or int(fnum) > 27):
        logger.warning(f'Incorrect GET parameter: {tab}')
        raise Http404
    if request.method == "POST":
        if tab == 'raw':
            form = RawInputForm(request.POST)
            if form.is_valid():
                with connection.cursor() as cursor:
                    query = form.cleaned_data['inp_query']
                    try:
                        cursor.execute(query)
                        output = cursor.fetchall()
                        output = [[str(j) for j in i] for i in output]
                        logger.info(f'raw query processed: {query}')
                    except ProgrammingError:
                        output = [['syntax error']]
                        logger.warning(f'raw query syntax error: {query}')
                    except IntegrityError:
                        output = [['FAIL']]
                        logger.warning(f'db cant process raw query: {query}')
                    except Exception as e:
                        output = [[f'error: {e}']]
                        logger.warning(f'error: {e}')
        else:
            form = fnc_forms.get(int(fnum))(request.POST)
            if form.is_valid():
                fcd = form.cleaned_data
                args = [
                    f"{fcd[i]}" if type(fcd[i]) == int else f"'{fcd[i]}'"
                    for i in form.cleaned_data
                ]
                res = _db_functions_handling(fnum, args)
                output = res.get('output')
                table_header = res.get('header')
                logger.info(f'processed function '
                            f'{_functions_names[int(fnum) - 1]}, args={args}')
            else:
                output = [['invalid input value']]
                logger.warning(f'invalid arguments entered for '
                               f'function {_functions_names[int(fnum) - 1]}')
    else:
        if fnum:
            form = _get_function_form(fnum)
            if form:
                tab = 'default'
            else:
                tab = 'functions'
                res = _db_functions_handling(fnum)
                output = res.get('output')
                table_header = res.get('header')
                logger.info(f'processed function '
                            f'{_functions_names[int(fnum) - 1]}, '
                            f'no args required')
                fnum = ''
        elif tab == 'raw':
            form = RawInputForm()
    return render(request, 'operations.html',
                  context={'tab': tab, 'fnum': fnum, 'output': output,
                           'table_header': table_header, 'input_form': form})


def _get_function_form(fnum):
    form = fnc_forms.get(int(fnum))
    if form:
        form = form()
    return form


_functions_names = [
    'pr_add_p2p',
    'pr_add_verter',
    'fn_get_transferred_points',
    'fn_get_user_task_xp_summary',
    'fn_find_on_campus_peers_for_day',
    'pr_calculate_check_success_percentage',
    'pr_calculate_peer_point_changes',
    'pr_calculate_peer_point_changes_from_transfered_points',
    'pr_find_most_frequently_checked_task_per_day',
    'pr_calculate_last_p2p_check_duration',
    'pr_find_peers_completed_block_of_tasks',
    'pr_assign_peer_for_check',
    'pr_calculate_block_progress_percentage',
    'pr_find_peers_with_most_friends',
    'pr_calculate_birthday_success_percentage',
    'pr_calculate_all_xp_by_peers',
    'pr_find_peers_with_specific_task_completion',
    'pr_count_previous_tasks',
    'pr_find_good_days',
    'pr_find_peer_with_most_completed_tasks',
    'pr_find_peer_with_most_xp',
    'pr_find_peer_with_most_time_on_campus_today',
    'pr_find_peers_who_came_before_time_N_times',
    'pr_find_peers_with_off_campus_frequency',
    'pr_find_last_arriving_peer_today',
    'pr_find_peers_with_long_off_campus_time_yesterday',
    'pr_calculate_monthly_early_entry_percentage'
]

_output_tables_headers = [
    ['peer1', 'peer2', 'points amount'],
    ['peer', 'task', 'xp'],
    ['peer'],
    ['successful_checks', 'unsuccessful_checks'],
    ['peer', 'points_change'],
    ['peer', 'points_change'],
    ['day', 'task'],
    ['check_duration'],
    ['peer', 'date'],
    ['peer', 'recommended_peer'],
    ['stated_block1', 'started_block2', 'started_both', 'didnt_start_any'],
    ['peer', 'friends_count'],
    ['successful_checks', 'unsuccessful_checks'],
    ['peer', 'xp'],
    ['peer'],
    ['task', 'prev_count'],
    ['lucky_days'],
    ['peer', 'number'],
    ['peer', 'xp'],
    ['peer'],
    ['peer'],
    ['peer'],
    ['peer'],
    ['peer'],
    ['month', 'early_entries'],
]


def _db_functions_handling(fnum, args=None):
    fnum = int(fnum)
    header = None
    if args:
        args_str = ', '.join(args)
    else:
        args_str = ''
    try:
        with connection.cursor() as cursor:
            if fnum in [1, 2]:
                command = f"CALL {_functions_names[fnum - 1]}({args_str});"
                cursor.execute(command)
                output = [['OK']]
            elif fnum in [3, 4, 5]:
                command = f"SELECT * " \
                          f"FROM {_functions_names[fnum - 1]}({args_str});"
                cursor.execute(command)
                output = cursor.fetchall()
                output = [[str(j) for j in i] for i in output]
            else:
                if args:
                    args_str = ', ' + args_str
                command = f"CALL {_functions_names[fnum - 1]}" \
                          f"(\'res\'{args_str}); FETCH ALL FROM \"res\";"
                cursor.execute(command)
                output = cursor.fetchall()
                output = [[str(j) for j in i] for i in output]
            if fnum > 2:
                header = _output_tables_headers[fnum - 3]
    except IntegrityError:
        output = [['FAIL']]
        logger.warning(f'db cant process function {_functions_names[fnum - 1]},'
                       f' args={args}')
    except Exception as e:
        output = [f'error: {e}']
        logger.warning(f'error: {e}')
    return {'header': header, 'output': output}


def operations_export(request):
    export_file = StringIO()
    if request.POST['table_header'] != 'None':
        header = ','.join(loads(request.POST['table_header']
                                .replace('\'', '\"'))) + '\n'
    else:
        header = None
    body = request.POST['output']
    body = loads(body.replace('\'', '\"'))
    body = '\n'.join([','.join(i) for i in body])
    if header:
        export_file.write(header + body)
    else:
        export_file.write(body)
    response = HttpResponse(export_file.getvalue(),
                            content_type='application/zip')
    response['Content-Disposition'] = 'attachment; filename=export.csv'
    logger.info('operations result table exported')
    return response
