import React, { useState } from 'react';
import { shallow, mount, ReactWrapper } from 'enzyme';
import { ReportsList } from './ReportsList';
import { ReportService } from "../services/ReportService";
import { act } from '@testing-library/react';
import { AppStateContext } from '../appStateContext';

describe('<ReportsList />', () => {
  it('should render without crashing', () => {
    shallow(<ReportsList loadReports={false} setLoadReports={jest.fn()} />);
  });

  it('should reload reports list', (done) => {
    const apiSpy = jest.spyOn(ReportService.prototype, 'list').mockResolvedValue([
      { id: 1, projectId: 1, title: 'a.docx', uri: 'http://fake.org/reports/123/a.docx' }
    ]);

    const Wrapper: React.FC = () => {
      const [loadReports, setLoadReports] = useState(true);
      return (
        <AppStateContext.Provider
          value={{appState: {
            activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false},
            runningProjects: []
          }, dispatch: jest.fn()}}
        >
          <ReportsList {...{loadReports, setLoadReports}} />
        </AppStateContext.Provider>
      );
    };

    let component: ReactWrapper;
    act(() => {
      component = mount(<Wrapper />);
    });

    setTimeout(() => {
      done();
      expect(apiSpy).toBeCalled();
      component.update();
      expect(component.find('a').text()).toMatch(new RegExp('a\.docx'));
    }, 0);
  });
});
